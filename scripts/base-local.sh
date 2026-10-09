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

DB="${DB:-morandana}"

# El puerto BASE de este repo. Va en pares entre repos hermanos para no gastar
# puertos: solo uno de cada par puede estar arriba a la vez, y la guardia de
# más abajo se niega a tocar el Postgres del hermano.
PUERTO_BASE=55434

# --- UN PUERTO POR ÁRBOL DE TRABAJO, NO POR REPO ------------------------------
#
# El `pgdata` siempre fue por árbol de trabajo —vive dentro del árbol— pero el
# puerto era del repo. Resultado: un worktree y su checkout principal levantaban
# DOS Postgres distintos peleando por el mismo puerto, y el que llegaba segundo
# terminaba hablándole a la base del primero. La guardia de puerto, de paso,
# veía al hermano como «de otro repo» y mandaba a apagarlo «desde SU repo», que
# era el mismo. Diagnosticado el 9-oct-2026.
#
# El checkout principal conserva el puerto documentado, para no romper lo que
# ya está escrito ni los `*_DB_URL=…` que la gente tenga a mano. Un worktree
# enlazado toma uno derivado de SU ruta, en un rango alto que no toca el bloque
# 5543x de los repos.
#
# `--git-dir` y `--git-common-dir` solo difieren en un worktree enlazado: es la
# forma barata de distinguirlos, sin depender de la ruta ni de convenciones.
puerto_del_arbol() {
  local comun propio h
  comun="$(git -C "$RAIZ" rev-parse --git-common-dir 2>/dev/null)" || { echo "$PUERTO_BASE"; return; }
  propio="$(git -C "$RAIZ" rev-parse --git-dir 2>/dev/null)"       || { echo "$PUERTO_BASE"; return; }
  [ "$comun" = "$propio" ] && { echo "$PUERTO_BASE"; return; }   # checkout principal
  # `cksum` es POSIX y da el mismo número en cada corrida: el puerto de un
  # worktree no puede cambiar entre invocaciones o `--stop` no encontraría nada.
  h="$(printf '%s' "$RAIZ" | cksum | awk '{print $1}')"
  echo $(( 55500 + h % 400 ))
}

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Después de RAIZ y atado a ella: un `git rev-parse` a secas miraría el cwd, y
# este script se invoca desde cualquier lado.
PUERTO="${PGPUERTO:-$(puerto_del_arbol)}"

# `--puerto` imprime el puerto de ESTE árbol y sale. Va aquí arriba, antes de
# buscar los binarios de Postgres: preguntar el puerto no necesita Postgres
# instalado, y el arnés lo pregunta en vez de recalcularlo —una copia del
# cálculo en la prueba haría que la prueba pase aunque el script se equivoque—.
# De paso contesta «¿en qué puerto quedó mi worktree?» sin leer el código.
if [ "${1:-}" = "--puerto" ]; then echo "$PUERTO"; exit 0; fi

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

# El puerto, antes de arrancar. Los puertos van en pares entre repos hermanos
# — 55433 MAP/medicarmen, 55432 shikomi/mise—, así que encontrarlo ocupado por
# otro repo es lo normal: solo puede haber uno de cada par arriba a la vez.
#
# Esto antes se "resolvía" con `kill -9` sobre cualquier cosa que escuchara,
# llamándola «postmaster huérfano» sin comprobarlo. En un clon nuevo eso mataba
# la base viva del repo hermano a SIGKILL, sin apagado limpio, dejándola en
# recuperación y con posible pérdida de WAL sin vaciar. Ahora se comprueba de
# quién es el proceso y, si no es nuestro, el script se niega y dice cómo
# apagarlo. No mata nada que no sea suyo.
AJENOS=""
puerto_de_otro() {
  command -v lsof >/dev/null 2>&1 || return 1
  local ocupantes mio p
  ocupantes="$(lsof -tiTCP:"$PUERTO" -sTCP:LISTEN 2>/dev/null)"
  [ -n "$ocupantes" ] || return 1
  mio=""
  if [ -f "$PGDATA/postmaster.pid" ]; then
    mio="$(head -1 "$PGDATA/postmaster.pid" 2>/dev/null)"
  fi
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    # Es el postmaster de ESTE datadir: no hay conflicto, `pg_ctl status` de
    # más abajo decide si hace falta arrancarlo.
    if [ -n "$mio" ] && [ "$p" = "$mio" ]; then return 1; fi
  done <<< "$ocupantes"
  AJENOS="$ocupantes"
  return 0
}

if puerto_de_otro; then
  echo "::error::El puerto $PUERTO lo tiene otro Postgres, y no es el de este repo." >&2
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    echo "  PID $p — $(ps -o command= -p "$p" 2>/dev/null)" >&2
  done <<< "$AJENOS"
  cat >&2 <<'AYUDA'

Apágalo desde SU repo, que cierra limpio:
    ./scripts/base-local.sh --stop

Si de verdad quedó huérfano (su repo ya no existe), apágalo a mano. Este
script no lo mata: un `kill -9` sobre un postmaster vivo deja la base en
recuperación y puede perder WAL sin vaciar.
AYUDA
  exit 1
fi


# --- Candado, antes de tocar el datadir ---------------------------------------
#
# DOS CORRIDAS A LA VEZ SE DESTRUYEN ENTRE SÍ. Sin candado, una hace `mkdir` de
# `pg_wal` mientras la otra está vaciando el directorio, y el resultado son
# estos dos errores --reproducidos el 8-oct-2026 lanzando dos invocaciones
# simultáneas--:
#
#   initdb: error: could not create directory ".../pg_wal": File exists
#   PANIC:  could not create file "global/pg_control": No such file or directory
#
# Ninguno de los dos menciona la concurrencia, y el `pgdata` queda corrupto:
# de ahí en adelante TODA corrida falla con «exists but is not empty», que
# tampoco dice que sea basura de una corrida abortada. Costó media hora
# diagnosticarlo creyendo que era un problema de worktrees.
#
# `mkdir` es la primitiva atómica aquí: o la crea este proceso, o ya existía.
# No se usa `flock`, que en macOS no viene de serie.
LOCK="$PGDATA.lock"
ESPERA="${BASE_LOCAL_ESPERA:-90}"   # segundos; 0 = no esperar
mkdir -p "$(dirname "$LOCK")"

# ESPERA EN VEZ DE FALLAR AL INSTANTE, y la razón salió de usarlo.
#
# La primera versión abortaba en cuanto encontraba el candado puesto. Eso
# convirtió una carrera que antes era silenciosa --y destructiva-- en un bloqueo
# duro: el hook de pre-commit puede lanzar la puerta dos veces, y la segunda
# moría sin remedio aunque la primera fuera a terminar en segundos. Un candado
# que no espera no serializa: solo mueve el problema.
#
# Ahora espera hasta $ESPERA segundos. Si el dueño termina, entra. Si no, falla
# con el mismo mensaje, que sigue siendo el caso que hay que poder ver.
inicio=$SECONDS
while :; do
  if mkdir "$LOCK" 2>/dev/null; then
    echo $$ > "$LOCK/pid"
    break
  fi
  DUENO="$(cat "$LOCK/pid" 2>/dev/null || echo '')"
  # Candado huérfano: su dueño ya no existe. Se toma sin esperar.
  if [ -z "$DUENO" ] || ! kill -0 "$DUENO" 2>/dev/null; then
    echo "→ candado huérfano de un proceso muerto; se reutiliza"
    rm -rf "$LOCK"
    continue
  fi
  if [ $((SECONDS - inicio)) -ge "$ESPERA" ]; then
    cat >&2 <<AYUDA
::error::Otra corrida de base-local lleva más de ${ESPERA}s levantando esta base (PID $DUENO).
  Dos a la vez corrompen el datadir, así que ésta no sigue. Si ese proceso
  quedó colgado, mátalo y borra el candado:
      rm -rf "$LOCK"
AYUDA
    exit 1
  fi
  [ $((SECONDS - inicio)) -eq 0 ] && echo "→ otra corrida tiene el candado (PID $DUENO); esperando…"
  sleep 1
done
trap 'rm -rf "$LOCK"' EXIT

# --- Residuo de una corrida abortada ------------------------------------------
#
# Un `pgdata` sin `base/` ni `PG_VERSION` no es una base: es lo que deja un
# initdb que se murió a medias. initdb se niega a escribir ahí con «exists but
# is not empty», un mensaje que no sugiere la salida. Se detecta y se dice.
if [ -d "$PGDATA" ] && [ ! -d "$PGDATA/base" ] && [ -n "$(ls -A "$PGDATA" 2>/dev/null)" ]; then
  echo "→ $PGDATA tiene restos de una corrida abortada (sin base/); se limpia"
  rm -rf "${PGDATA:?}"
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
