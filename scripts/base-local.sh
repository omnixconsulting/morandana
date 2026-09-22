#!/usr/bin/env bash
# Levanta un Postgres local con TODAS las migraciones aplicadas, para probar las
# políticas RLS sin depender del proyecto remoto ni de Docker (`supabase start`
# necesita Docker; este script no).
#
#   ./scripts/base-local.sh            # (re)crea la base y aplica migraciones
#   ./scripts/base-local.sh --stop     # detiene el servidor
#
# Las migraciones asumen Supabase, así que primero se crea el andamiaje mínimo:
# los roles anon/authenticated/service_role y un stub de `storage` (la migración
# de ig_posts inserta un bucket y define una política sobre storage.objects).
# No hay stub de `auth`: morandana no usa auth.uid() en ninguna política.
#
# SOBRE LOS PRIVILEGIOS DE `anon` — importa para que la prueba signifique algo.
# Antes de las migraciones se aplican los privilegios por omisión de Supabase
# (`alter default privileges`), de modo que las tablas que crean las migraciones
# nazcan con el acceso amplio que tendrían en el proyecto hospedado. Después,
# `20260922120000_privilegios_explicitos.sql` los revoca y concede solo lo que
# el sitio usa — igual que hará en producción.
#
# El orden es el punto: si el andamiaje concediera DESPUÉS de las migraciones,
# borraría el efecto de esa migración y la prueba pasaría por un permiso que
# producción no tiene. Y si no concediera nada, las negativas vendrían por falta
# de privilegio en vez de por la política, que es el otro falso verde.

set -euo pipefail
export LC_ALL="${LC_ALL:-C}"
export LANG="${LANG:-C}"

PUERTO="${PGPUERTO:-55434}"
DB="${DB:-morandana}"
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -x /opt/homebrew/opt/postgresql@17/bin/pg_ctl ]; then
  BIN=/opt/homebrew/opt/postgresql@17/bin
elif command -v pg_ctl >/dev/null 2>&1; then
  BIN="$(dirname "$(command -v pg_ctl)")"
else
  BIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
fi
[ -n "${BIN:-}" ] || { echo "No encuentro initdb/pg_ctl. Instala Postgres 17." >&2; exit 1; }
PSQL="$BIN/psql"

if [ "$(id -u)" = 0 ] && id postgres >/dev/null 2>&1; then
  como_pg() { su postgres -c "$(printf '%q ' "$@")"; }
  PGDATA="${PGDATA:-/var/lib/postgresql/morandana}"
  ROOTFUL=1
else
  como_pg() { "$@"; }
  PGDATA="${PGDATA:-$RAIZ/.base-local/pgdata}"
  ROOTFUL=0
fi

stop_server() { como_pg "$BIN/pg_ctl" -D "$PGDATA" -m fast stop >/dev/null 2>&1 || true; }
if [ "${1:-}" = "--stop" ]; then stop_server; echo "base-local: servidor detenido."; exit 0; fi

if [ ! -d "$PGDATA/base" ] && command -v lsof >/dev/null 2>&1; then
  if lsof -tiTCP:"$PUERTO" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "→ liberando el puerto $PUERTO (postmaster huérfano)"
    lsof -tiTCP:"$PUERTO" -sTCP:LISTEN | xargs kill -9 2>/dev/null || true
    sleep 1
  fi
fi

if [ ! -d "$PGDATA/base" ]; then
  echo "→ initdb en $PGDATA"
  mkdir -p "$PGDATA"
  [ "$ROOTFUL" = 1 ] && chown -R postgres:postgres "$PGDATA"
  como_pg "$BIN/initdb" -D "$PGDATA" -U postgres -A trust -E UTF8 >/dev/null
fi

if ! como_pg "$BIN/pg_ctl" -D "$PGDATA" status >/dev/null 2>&1; then
  echo "→ arrancando Postgres en el puerto $PUERTO"
  como_pg "$BIN/pg_ctl" -D "$PGDATA" \
    -o "-p $PUERTO -c listen_addresses=localhost -c unix_socket_directories=/tmp" \
    -l "$PGDATA/server.log" start >/dev/null
  sleep 2
fi

Q() { "$PSQL" -h localhost -p "$PUERTO" -U postgres -q -v ON_ERROR_STOP=1 "$@"; }

echo "→ recreando la base '$DB'"
Q -c "drop database if exists $DB;"
Q -c "create database $DB;"

echo "→ andamiaje de Supabase (roles, storage)"
Q -d "$DB" <<'SQL'
do $$ begin
  if not exists (select 1 from pg_roles where rolname='anon') then create role anon nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname='authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select 1 from pg_roles where rolname='service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;

create schema if not exists storage;
create table if not exists storage.buckets (
  id text primary key, name text, public boolean default false, created_at timestamptz default now()
);
create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text, name text, owner uuid, metadata jsonb, created_at timestamptz default now()
);
alter table storage.objects enable row level security;
grant usage on schema storage to anon, authenticated, service_role;
grant select on storage.objects to anon, authenticated;
grant all on storage.buckets, storage.objects to service_role;

grant usage on schema public to anon, authenticated, service_role;

-- Privilegios por omisión de Supabase: las tablas que creen las migraciones
-- nacen con acceso amplio para anon/authenticated. La migración de privilegios
-- explícitos los recorta después, igual que en el proyecto hospedado.
alter default privileges in schema public
  grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges in schema public
  grant usage, select on sequences to anon, authenticated, service_role;
SQL

echo "→ aplicando migraciones"
for f in "$RAIZ"/supabase/migrations/*.sql; do
  if out=$(Q -d "$DB" -f "$f" 2>&1); then
    printf '   ok    %s\n' "$(basename "$f")"
  else
    printf '   FALLA %s\n%s\n' "$(basename "$f")" "$out"
    exit 1
  fi
done

echo
echo "Listo — postgresql://postgres@localhost:$PUERTO/$DB"
echo "  ./scripts/test-db.sh"
