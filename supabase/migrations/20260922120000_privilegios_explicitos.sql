-- Morandana — privilegios explícitos de `anon`.
--
-- Hasta aquí el repo no versionaba ningún GRANT, así que los permisos efectivos
-- del sitio vivían en los valores por omisión del proyecto hospedado: fuera de
-- git, fuera de revisión y fuera de CI. Esta migración los trae al repo.
--
-- Importa más de lo que parece: todo el sitio habla con Supabase por
-- NEXT_PUBLIC_SUPABASE_ANON_KEY, que viaja en el bundle del navegador y
-- cualquiera extrae. `anon` no es un rol interno — es cualquier visitante.

-- Punto de partida limpio. `service_role` no se toca: el dashboard y cualquier
-- tarea administrativa siguen entrando por ahí.
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

grant usage on schema public to anon, authenticated;

-- Lo único que el sitio necesita, verificado contra el código:
--   src/lib/menu.ts → select de menu_items
--   src/lib/ig.ts   → select de ig_posts
-- La RLS ya acota ambas a `is_active = true`; el grant acota el verbo.
grant select on public.menu_items to anon, authenticated;
grant select on public.ig_posts   to anon, authenticated;

-- ---------------------------------------------------------------------------
-- leads
-- ---------------------------------------------------------------------------
-- La tabla no tiene uso. Ningún archivo del repo la lee ni la escribe: el
-- contacto del sitio va por WhatsApp (src/components/WhatsAppChat.tsx).
--
-- Tenía una política de INSERT para `anon` con `with check (true)` — es decir,
-- un endpoint de escritura sin autenticar ni acotar, abierto a cualquiera que
-- tome la llave pública del bundle, alimentando una tabla que nadie consulta.
-- Se cierra por ahora.
--
-- La tabla y sus filas se conservan. Cuando exista el formulario de contacto,
-- esto se reabre en la misma migración que lo agregue:
--   create policy "leads anon insert" on public.leads
--     for insert to anon with check (true);
--   grant insert on public.leads to anon;
-- y conviene que entonces traiga algún límite de tasa, que hoy no tiene.
drop policy if exists "leads anon insert" on public.leads;
