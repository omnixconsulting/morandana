-- Morandana — esquema inicial
-- Tablas: menu_items (contenido del menú) y leads (captura de contacto).
-- RLS activado en ambas con políticas mínimas y seguras.

-- ---------------------------------------------------------------------------
-- menu_items
-- ---------------------------------------------------------------------------
create table if not exists public.menu_items (
  id          uuid primary key default gen_random_uuid(),
  category    text not null check (category in ('am', 'pm', 'bebidas')),
  name        text not null,
  description text,
  price       text not null,              -- etiqueta de precio (p. ej. "$150", "desde $90")
  image_path  text,                       -- ruta del asset en /public (o URL de Storage)
  img_position text,                       -- object-position para la tarjeta (opcional)
  sort_order  int  not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists menu_items_category_sort_idx
  on public.menu_items (category, sort_order);

alter table public.menu_items enable row level security;

-- Lectura pública solo de platillos activos.
drop policy if exists "menu_items public read" on public.menu_items;
create policy "menu_items public read"
  on public.menu_items
  for select
  to anon, authenticated
  using (is_active = true);

-- (Escrituras: sin política para anon → solo service_role / dashboard pueden editar.)

-- ---------------------------------------------------------------------------
-- leads (formulario de contacto / interesados)
-- ---------------------------------------------------------------------------
create table if not exists public.leads (
  id         uuid primary key default gen_random_uuid(),
  name       text,
  email      text,
  phone      text,
  message    text,
  source     text not null default 'landing',
  created_at timestamptz not null default now()
);

alter table public.leads enable row level security;

-- El público puede enviar (insertar) un lead, pero no leer los de nadie.
drop policy if exists "leads anon insert" on public.leads;
create policy "leads anon insert"
  on public.leads
  for insert
  to anon, authenticated
  with check (true);
