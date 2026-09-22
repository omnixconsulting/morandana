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
-- Estructural: ninguna tabla de `public` sin RLS y sin política.
-- No enumera tablas, las descubre: la tabla que alguien agregue mañana y olvide
-- proteger falla aquí, que es justo lo que una lista escrita a mano deja pasar.
-- ---------------------------------------------------------------------------
do $$
declare faltan text;
begin
  select string_agg(c.relname || '(rls=' || c.relrowsecurity || ', políticas=' ||
                    (select count(*) from pg_policy p where p.polrelid = c.oid) || ')', ', ')
    into faltan
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
    and (not c.relrowsecurity or (select count(*) from pg_policy p where p.polrelid = c.oid) = 0);
  if faltan is not null then raise exception 'Tablas de public sin RLS o sin política: %', faltan; end if;
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

  -- LA QUE IMPORTA: leads no se lee. Es PII de terceros.
  select count(*) into n from public.leads;
  if n <> 0 then raise exception 'anon LEE leads — PII expuesta (% filas)', n; end if;

  -- Pero el formulario de contacto sí funciona.
  insert into public.leads (name, email, message) values ('Beto Prueba', 'beto@prueba.test', 'Hola');

  -- No escribe el menú.
  begin
    insert into public.menu_items (category, name, price) values ('am', 'INTRUSO', '$1');
    raise exception 'anon insertó en el menú';
  exception when insufficient_privilege then null;
  end;

  update public.menu_items set name = 'HACKEADO';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'anon modificó % platillo(s)', n; end if;

  delete from public.menu_items;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'anon borró % platillo(s)', n; end if;

  -- Ni el feed.
  begin
    insert into public.ig_posts (image_url) values ('/intruso.jpg');
    raise exception 'anon insertó en el feed';
  exception when insufficient_privilege then null;
  end;

  delete from public.ig_posts;
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'anon borró % publicación(es) del feed', n; end if;

  -- Storage: ve el bucket público del feed.
  select count(*) into n from storage.objects where bucket_id = 'ig';
  if n <> 1 then raise exception 'anon no ve los objetos del bucket ig (%)', n; end if;
end $$;

reset role;

rollback;
