-- Morandana — feed de Instagram curado (Plan C2).
-- Tabla ig_posts + bucket de Storage 'ig' para las fotos. Actualización sin
-- deploy: agregar filas / subir imágenes desde el dashboard de Supabase.

create table if not exists public.ig_posts (
  id         uuid primary key default gen_random_uuid(),
  image_url  text not null,               -- URL pública (Storage) o ruta /public
  post_url   text,                         -- link a la publicación de Instagram
  caption    text,
  sort_order int  not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists ig_posts_sort_idx on public.ig_posts (sort_order);

alter table public.ig_posts enable row level security;

drop policy if exists "ig_posts public read" on public.ig_posts;
create policy "ig_posts public read"
  on public.ig_posts
  for select
  to anon, authenticated
  using (is_active = true);

-- Bucket público para las fotos del feed.
insert into storage.buckets (id, name, public)
values ('ig', 'ig', true)
on conflict (id) do nothing;

drop policy if exists "ig bucket public read" on storage.objects;
create policy "ig bucket public read"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'ig');
