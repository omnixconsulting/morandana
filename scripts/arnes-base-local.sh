#!/usr/bin/env bash
# Arnés del chequeo de puerto de `base-local.sh` (§5.7).
#
# Lo que este arnés existe para impedir: que el script vuelva a matar la base de
# otro repo. Los puertos van en pares entre repos hermanos, así que el caso
# «el puerto está ocupado» es normal, y antes se resolvía con `kill -9` sobre
# cualquier cosa que escuchara. La aserción que importa no es que el script
# falle: es que el proceso ajeno SIGA VIVO después.
#
# Levanta su propio Postgres en un puerto y un datadir temporales. No toca el
# datadir del repo ni ningún puerto de los pares.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ="$PWD"
SCRIPT="$RAIZ/scripts/base-local.sh"

# La MISMA deteccion que base-local.sh, las tres ramas incluida la de Ubuntu
# (`/usr/lib/postgresql/*/bin`): el runner no trae pg_ctl en el PATH, y sin esa
# tercera rama el arnes no media nada en CI. Si cambia alla, cambia aqui.
if [ -x /opt/homebrew/opt/postgresql@17/bin/pg_ctl ]; then
  BIN=/opt/homebrew/opt/postgresql@17/bin
elif command -v pg_ctl >/dev/null 2>&1; then
  BIN="$(dirname "$(command -v pg_ctl)")"
else
  BIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "${BIN:-}" ] || [ ! -x "$BIN/pg_ctl" ]; then
  echo "::error::no encuentro pg_ctl; el arnés de base-local no puede medir nada" >&2
  exit 1
fi

TMP="$(mktemp -d)"
AJENO="$TMP/ajeno"
PUERTO_PRUEBA=55995

# Limpia TODO lo que quede en el puerto de prueba cuyo datadir esté bajo $TMP,
# no solo el Postgres que este arnés levantó. Hace falta: un `base-local.sh`
# roto puede arrancar el suyo —el código viejo mataba al ajeno y se quedaba con
# el puerto—, y ese huérfano trabaría la siguiente corrida del arnés.
limpiar() {
  "$BIN/pg_ctl" -D "$AJENO" -m fast stop >/dev/null 2>&1 || true
  local p
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$(ps -o command= -p "$p" 2>/dev/null)" in
      *"$TMP"*) kill -TERM "$p" 2>/dev/null || true ;;
    esac
  done <<< "$(lsof -tiTCP:"$PUERTO_PRUEBA" -sTCP:LISTEN 2>/dev/null)"
  sleep 1
  rm -rf "$TMP"
}
trap limpiar EXIT

fallos=0
ok()  { echo "  ✓ $1"; }
mal() { echo "  ✗ $1"; fallos=$((fallos+1)); }

echo "Arnés del chequeo de puerto de base-local:"

# Un Postgres "de otro repo" en el puerto de prueba.
LC_ALL=C "$BIN/initdb" -D "$AJENO" -U postgres -A trust -E UTF8 >/dev/null 2>&1
LC_ALL=C "$BIN/pg_ctl" -D "$AJENO" \
  -o "-p $PUERTO_PRUEBA -c listen_addresses=localhost -c unix_socket_directories=/tmp" \
  -l "$AJENO/server.log" start >/dev/null 2>&1
sleep 2
PID_AJENO="$(head -1 "$AJENO/postmaster.pid" 2>/dev/null)"
if [ -z "$PID_AJENO" ] || ! kill -0 "$PID_AJENO" 2>/dev/null; then
  echo "::error::el arnés no pudo levantar su Postgres de prueba; no midió nada" >&2
  exit 1
fi
echo "  (Postgres ajeno de prueba: PID $PID_AJENO en el puerto $PUERTO_PRUEBA)"

corre() {   # corre base-local.sh con un datadir y puerto dados
  PGDATA="$1" PGPUERTO="$PUERTO_PRUEBA" bash "$SCRIPT" 2>&1
}

# --- 1. Clon nuevo: nuestro datadir no existe y el puerto está ocupado -------
salida="$(corre "$TMP/no-existe")"; codigo=$?
[ "$codigo" -ne 0 ] \
  && ok "clon nuevo con el puerto ocupado: el script se niega" \
  || mal "clon nuevo con el puerto ocupado: el script NO se negó"
printf '%s' "$salida" | grep -qF "no es el de este repo" \
  && ok "el mensaje dice que el puerto es de otro repo" \
  || mal "el mensaje no explica de quién es el puerto"
printf '%s' "$salida" | grep -qF -- "$AJENO" \
  && ok "el mensaje nombra el datadir ajeno" \
  || mal "el mensaje no nombra el datadir ajeno"

# LA aserción: el ajeno sigue vivo.
kill -0 "$PID_AJENO" 2>/dev/null \
  && ok "el Postgres ajeno SIGUE VIVO (la regresión que esto impide)" \
  || mal "el Postgres ajeno MURIÓ: volvió la regresión del kill -9"

# --- 2. Pidfile rancio: nuestro datadir existe, su PID ya no escucha ---------
RANCIO="$TMP/rancio"
mkdir -p "$RANCIO/base"
echo 999999 > "$RANCIO/postmaster.pid"
salida="$(corre "$RANCIO")"; codigo=$?
# Mide el MENSAJE, no solo el código: con el `kill -9` viejo este caso también
# salía distinto de cero, pero por «could not start server» después de haber
# matado al ajeno. El código de salida no distingue las dos cosas.
{ [ "$codigo" -ne 0 ] && printf '%s' "$salida" | grep -qF "no es el de este repo"; } \
  && ok "pidfile rancio y puerto ajeno: se niega explicándolo, no con «could not start server»" \
  || mal "pidfile rancio: no se negó con el mensaje del chequeo de puerto"
kill -0 "$PID_AJENO" 2>/dev/null \
  && ok "el ajeno sigue vivo también en el caso del pidfile rancio" \
  || mal "el ajeno murió en el caso del pidfile rancio"

# --- 3. Sin falso positivo: el postmaster del puerto es NUESTRO -------------
# Mismo datadir que el "ajeno": desde el punto de vista del script, es suyo.
salida="$(corre "$AJENO")"
printf '%s' "$salida" | grep -qF "no es el de este repo" \
  && mal "falso positivo: se negó aunque el postmaster del puerto es suyo" \
  || ok "no se niega cuando el postmaster del puerto es de su propio datadir"

# --- 4. Puerto libre: tampoco se niega --------------------------------------
"$BIN/pg_ctl" -D "$AJENO" -m fast stop >/dev/null 2>&1
sleep 1
salida="$(corre "$TMP/libre")"
printf '%s' "$salida" | grep -qF "no es el de este repo" \
  && mal "falso positivo: se negó con el puerto libre" \
  || ok "con el puerto libre no se niega"

echo
if [ "$fallos" -gt 0 ]; then
  echo "::error::Arnés de base-local: $fallos aserción(es) en rojo."
  exit 1
fi
echo "Arnés de base-local: las 8 aserciones en verde."
