#!/usr/bin/env bash
# Arnes de CONCURRENCIA de `base-local.sh` (§5.7).
#
# POR QUE EXISTE
# El 8-oct-2026 dos invocaciones simultaneas se destruyeron entre si: una hacia
# `mkdir` de `pg_wal` mientras la otra vaciaba el directorio. Los dos errores
# que salen no mencionan la concurrencia --
#
#   initdb: error: could not create directory ".../pg_wal": File exists
#   PANIC:  could not create file "global/pg_control": No such file or directory
#
# -- y el datadir queda corrupto, asi que de ahi en adelante TODA corrida falla
# con «exists but is not empty», que tampoco dice que sea basura. Costo media
# hora diagnosticarlo creyendo que era un problema de worktrees.
#
# El arnes del puerto (`arnes-base-local.sh`) NO cubre esto: prueba que el
# script no mate la base de otro repo, que es un caso distinto.
#
# Usa un PGDATA y un puerto TEMPORALES: no toca el datadir del repo ni los
# puertos de los repos hermanos.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
fallos=0

# Un puerto alto y poco probable, para no chocar con ningun par de repos.
export PGPUERTO=55497
export PGDATA="$TMP/pgdata"

apagar() { PGDATA="$PGDATA" PGPUERTO="$PGPUERTO" ./scripts/base-local.sh --stop >/dev/null 2>&1 || true; }
trap 'apagar; rm -rf "$TMP"' EXIT

echo 'Arnes de concurrencia de base-local:'

# --- 1) dos a la vez: una gana, la otra lo dice, y NADA se corrompe ----------
#
# OJO CON LA ASERCION DE «no se corrompe»: es el SINTOMA, y una carrera es no
# determinista. Se comprobo quitando el candado: ese caso paso igual, porque la
# limpieza de residuo tapo el destrozo y porque la ventana de carrera no se
# abrio esa vez. Se queda porque es lo que el usuario ve, pero NO es lo que
# guarda el candado.
#
# Las dos aserciones DETERMINISTAS son «la que pierde avisa» --sin candado no
# hay nada que avisar-- y el caso 2 del candado huerfano. Esas dos son las que
# salieron rojas al quitarlo. Si alguien recorta este arnes, que recorte la
# primera, no esas.
( ./scripts/base-local.sh > "$TMP/a.log" 2>&1 ) &
( ./scripts/base-local.sh > "$TMP/b.log" 2>&1 ) &
wait

corrupcion=$(grep -hcE 'PANIC|pg_wal.*File exists|failed to remove contents' "$TMP/a.log" "$TMP/b.log" | paste -sd+ - | bc)
listos=$(grep -hc 'Listo' "$TMP/a.log" "$TMP/b.log" | paste -sd+ - | bc)
espero=$(grep -hc 'esperando' "$TMP/a.log" "$TMP/b.log" | paste -sd+ - | bc)

if [ "$corrupcion" != "0" ]; then
  echo '  MAL  dos corridas simultaneas CORROMPIERON el datadir'
  grep -hE 'PANIC|pg_wal|failed to remove' "$TMP/a.log" "$TMP/b.log" | sed 's/^/         /' | head -3
  fallos=1
else
  echo '  ok   dos simultaneas no corrompen el datadir'
fi
# Con espera, las dos TERMINAN: la segunda se forma y entra cuando la primera
# suelta. Serializar es el objetivo; abortar a la segunda solo movia el problema.
if [ "$listos" != "2" ]; then
  echo "  MAL  se esperaba que las DOS terminaran serializadas; terminaron $listos"
  fallos=1
else
  echo '  ok   las dos terminan, serializadas'
fi
if [ "$espero" -lt 1 ]; then
  echo '  MAL  ninguna dijo que estaba esperando el candado'
  fallos=1
else
  echo '  ok   la segunda dice que espera, no muere'
fi

apagar

# --- 1b) un candado que NO se suelta: espera lo acordado y falla ------------
#
# Determinista, a diferencia de la carrera: se pone el candado a nombre de un
# proceso vivo de verdad (un `sleep`) y se exige que el script espere y despues
# falle. Con ESPERA=2 la prueba tarda dos segundos, no noventa.
rm -rf "$PGDATA" "$PGDATA.lock"
mkdir -p "$PGDATA.lock"
sleep 30 & RETEN=$!
echo $RETEN > "$PGDATA.lock/pid"
salida=$(BASE_LOCAL_ESPERA=2 ./scripts/base-local.sh 2>&1); codigo=$?
kill $RETEN 2>/dev/null; wait $RETEN 2>/dev/null
if [ "$codigo" -ne 0 ] && printf '%s' "$salida" | grep -q 'levantando esta base'; then
  echo '  ok   un candado que no suelta: espera y falla diciendo de quien es'
else
  echo "  MAL  no respeto el tope de espera (exit $codigo)"
  fallos=1
fi
rm -rf "$PGDATA.lock"

# --- 2) candado huerfano: un PID muerto no bloquea para siempre --------------
rm -rf "$PGDATA" "$PGDATA.lock"
mkdir -p "$PGDATA.lock"
# Un PID que seguro no existe: el maximo del sistema mas uno nunca esta vivo.
echo 99999999 > "$PGDATA.lock/pid"
salida=$(./scripts/base-local.sh 2>&1); codigo=$?
if [ "$codigo" -eq 0 ] && printf '%s' "$salida" | grep -q 'huerfano\|huérfano'; then
  echo '  ok   un candado de un proceso muerto se reutiliza, no bloquea'
else
  echo "  MAL  un candado huerfano dejo el script atorado (exit $codigo)"
  printf '%s\n' "$salida" | tail -3 | sed 's/^/         /'
  fallos=1
fi
apagar

# --- 3) residuo de una corrida abortada --------------------------------------
#
# Un pgdata con algo adentro pero sin `base/` es lo que deja un initdb muerto a
# medias. Antes el script le pasaba al usuario el «exists but is not empty» de
# initdb, que no sugiere la salida.
rm -rf "$PGDATA" "$PGDATA.lock"
mkdir -p "$PGDATA/global"
touch "$PGDATA/PG_VERSION"
salida=$(./scripts/base-local.sh 2>&1); codigo=$?
if [ "$codigo" -eq 0 ] && printf '%s' "$salida" | grep -q 'restos de una corrida abortada'; then
  echo '  ok   limpia el residuo de una corrida abortada y sigue'
else
  echo "  MAL  no se recupero de un pgdata a medias (exit $codigo)"
  printf '%s\n' "$salida" | grep -E 'error|not empty' | head -2 | sed 's/^/         /'
  fallos=1
fi
apagar

echo
if [ "$fallos" -eq 0 ]; then
  echo 'Arnes de concurrencia: el candado aguanta.'
else
  echo '::error::base-local puede corromper su datadir con dos corridas a la vez.'
fi
exit "$fallos"
