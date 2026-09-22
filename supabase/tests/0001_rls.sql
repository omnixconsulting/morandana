-- Pruebas L2: qué puede hacer `anon` en morandana.
--
-- El sitio entero habla con Supabase por la llave `anon`, que viaja en el
-- bundle del navegador (NEXT_PUBLIC_SUPABASE_ANON_KEY). Cualquiera la extrae.
-- Eso no es un defecto —es cómo funciona Supabase— pero deja una consecuencia:
-- **RLS es lo único que separa a un visitante de los datos.**
--
-- La aserción que más importa está en el bloque de `leads`: esa tabla guarda
-- nombre, correo, teléfono y mensaje de personas reales. Si su política se
-- rompe, cualquier visitante cosecha los contactos y nadie se entera.
--
-- Cómo se manifiesta una negativa de RLS, que es lo que estas pruebas afirman:
--   SELECT sin política que lo permita → 0 filas, SIN error.
--   SELECT/INSERT sin GRANT            → excepción 42501.
--   INSERT que viola la política       → excepción 42501.
--   UPDATE/DELETE sin filas visibles   → 0 filas afectadas, SIN error.

begin;

-- ---------------------------------------------------------------------------
-- Semilla
-- ---------------------------------------------------------------------------
insert into public.menu_items (category, name, price, is_active) values
  ('am', 'PRUEBA-VISIBLE', '$100', true),
  ('am', 'PRUEBA-OCULTO',  '$100', false);

insert into public.ig_posts (image_url, caption, is_active) values
  ('/prueba-visible.jpg', 'PRUEBA-VISIBLE', true),
  ('/prueba-oculto.jpg',  'PRUEBA-OCULTO',  false);

insert into public.leads (name, email, phone, message) values
  ('Ana Prueba', 'ana@prueba.test', '+525555550100', 'Hola');

insert into storage.objects (bucket_id, name) values ('ig', 'prueba.jpg');

-- ---------------------------------------------------------------------------
-- Estructural: ninguna tabla de `public` con la RLS apagada.
-- No enumera tablas, las descubre: la tabla que alguien agregue mañana y olvide
-- proteger falla aquí, que es justo lo que una lista escrita a mano deja pasar.
--
-- No se exige "al menos una política". Con RLS activa y cero políticas el
-- resultado es deny-all, que es el estado MÁS cerrado, no un olvido — es
-- justamente lo que se quiere para `leads`. Lo peligroso es la RLS apagada,
-- donde solo el GRANT decide.
-- ---------------------------------------------------------------------------
do $$
declare faltan text;
begin
  select string_agg(c.relname, ', ') into faltan
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
  if faltan is not null then raise exception 'Tablas de public sin RLS: %', faltan; end if;
end $$;

-- ---------------------------------------------------------------------------
-- Privilegios de `anon`, tabla por tabla y verbo por verbo.
--
-- La RLS filtra filas; el GRANT decide si el verbo existe siquiera. Las dos
-- capas tienen que estar bien, y hasta la migración de privilegios explícitos
-- esta mitad no vivía en el repo.
-- ---------------------------------------------------------------------------
do $$
declare real text; esperado text := 'ig_posts:SELECT | menu_items:SELECT';
begin
  select coalesce(string_agg(t.fila, ' | ' order by t.fila), '(ninguno)') into real
  from (
    select table_name || ':' || string_agg(privilege_type, ',' order by privilege_type) as fila
    from information_schema.role_table_grants
    where grantee = 'anon' and table_schema = 'public'
    group by table_name
  ) t;
  if real <> esperado then
    raise exception 'Privilegios de anon cambiaron. Esperado [%] — real [%]', esperado, real;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- anon
-- ---------------------------------------------------------------------------
set local role anon;

do $$
declare n int;
begin
  -- menu_items: ve lo activo y NO ve lo inactivo.
  select count(*) into n from public.menu_items where name = 'PRUEBA-OCULTO';
  if n <> 0 then raise exception 'anon ve platillos inactivos'; end if;

  select count(*) into n from public.menu_items where name = 'PRUEBA-VISIBLE';
  if n <> 1 then raise exception 'anon no ve el menú público (%)', n; end if;

  -- ig_posts: mismo trato.
  select count(*) into n from public.ig_posts where caption = 'PRUEBA-OCULTO';
  if n <> 0 then raise exception 'anon ve publicaciones inactivas'; end if;

  select count(*) into n from public.ig_posts where caption = 'PRUEBA-VISIBLE';
  if n <> 1 then raise exception 'anon no ve el feed público (%)', n; end if;

  -- LA QUE IMPORTA: leads no se lee. Es PII de terceros (nombre, correo,
  -- teléfono, mensaje). Desde la migración de privilegios explícitos hay dos
  -- capas: `anon` no tiene el GRANT, y la tabla no tiene política. Cualquiera
  -- de las dos por sí sola bastaría; se afirman las dos porque quitar una es
  -- exactamente el cambio que nadie notaría.
  begin
    select count(*) into n from public.leads;
    raise exception 'anon LEE leads — PII expuesta (% filas)', n;
  exception when insufficient_privilege then null;
  end;

  -- Y tampoco escribe. La tabla no tiene uso —el contacto va por WhatsApp— así
  -- que desde `20260922120000_privilegios_explicitos.sql` no hay ni política de
  -- INSERT ni grant. Antes había un endpoint de escritura abierto a cualquiera
  -- con la llave pública, alimentando una tabla que nadie consulta.
  begin
    insert into public.leads (name, email, message) values ('Beto Prueba', 'beto@prueba.test', 'Hola');
    raise exception 'anon insertó en leads';
  exception when insufficient_privilege then null;
  end;

  -- No escribe el menú ni el feed. Con los privilegios explícitos `anon` solo
  -- tiene SELECT, así que la negativa llega antes que la política: el verbo no
  -- existe para ese rol. Es una capa más arriba que la RLS y por eso se afirma
  -- aparte — si alguien volviera a conceder el verbo, la política sería lo
  -- único que quedaría, y esta prueba lo diría.
  begin
    insert into public.menu_items (category, name, price) values ('am', 'INTRUSO', '$1');
    raise exception 'anon insertó en el menú';
  exception when insufficient_privilege then null;
  end;

  begin
    update public.menu_items set name = 'HACKEADO';
    raise exception 'anon modificó el menú';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from public.menu_items;
    raise exception 'anon borró del menú';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.ig_posts (image_url) values ('/intruso.jpg');
    raise exception 'anon insertó en el feed';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from public.ig_posts;
    raise exception 'anon borró del feed';
  exception when insufficient_privilege then null;
  end;

  -- Storage: ve el bucket público del feed.
  select count(*) into n from storage.objects where bucket_id = 'ig';
  if n <> 1 then raise exception 'anon no ve los objetos del bucket ig (%)', n; end if;
end $$;

reset role;

rollback;
