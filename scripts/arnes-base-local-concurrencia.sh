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

# --- un puerto por arbol de trabajo, no por repo -----------------------------
#
# El pgdata siempre fue por worktree, pero el puerto era del repo: un worktree y
# su checkout principal levantaban DOS Postgres peleando por el mismo puerto, y
# el segundo terminaba hablandole a la base del primero.
#
# Se monta un repo de JUGUETE con su worktree en $TMP y se le pregunta el puerto
# a cada arbol. Hermetico a proposito: comparar contra el checkout principal de
# verdad (a) no corre en CI, donde no hay worktree, (b) depende de la forma del
# Mac de quien lo corra y (c) ejecuta el base-local.sh de OTRA rama, que puede
# arrancar un Postgres que nadie pidio. Aqui solo se pregunta, nada arranca.
echo
echo 'Arnes del puerto por arbol de trabajo:'

# Se le PREGUNTA al script (`--puerto`), no se recalcula: una copia del calculo
# aqui haria que la prueba pase aunque el script se equivoque.
puerto_de() { ( cd "$1" && PGPUERTO= PGDATA= ./scripts/base-local.sh --puerto 2>/dev/null ); }

REPO="$TMP/repo"
mkdir -p "$REPO/scripts"
cp ./scripts/base-local.sh "$REPO/scripts/base-local.sh"
git -C "$REPO" init -q
git -C "$REPO" -c user.email=a@b -c user.name=a commit -q --allow-empty -m x
git -C "$REPO" worktree add -q "$TMP/arbol" -b rama-de-prueba >/dev/null 2>&1
mkdir -p "$TMP/arbol/scripts"
cp ./scripts/base-local.sh "$TMP/arbol/scripts/base-local.sh"

base=$(grep -m1 '^PUERTO_BASE=' ./scripts/base-local.sh | cut -d= -f2)
p_principal="$(puerto_de "$REPO")"
p_arbol="$(puerto_de "$TMP/arbol")"

# a) el checkout principal conserva el puerto documentado. Es la promesa que
#    protege los `*_DB_URL=` que la gente ya tiene a mano.
if [ "$p_principal" = "$base" ]; then
  echo "  ok   el checkout principal conserva su puerto documentado ($base)"
else
  echo "  MAL  el principal deberia dar $base y dio '$p_principal'"
  fallos=1
fi

# b) el worktree toma otro. Esta es la asercion que sale roja si alguien
#    devuelve `puerto_del_arbol` a un `echo $PUERTO_BASE` incondicional.
if [ -n "$p_arbol" ] && [ "$p_arbol" != "$p_principal" ]; then
  echo "  ok   el worktree toma otro puerto ($p_arbol), no el del repo"
else
  echo "  MAL  worktree='$p_arbol' principal='$p_principal' — comparten puerto"
  fallos=1
fi

# c) y ese puerto es ESTABLE entre invocaciones. Sin esto, `--stop` buscaria en
#    un puerto distinto al que arranco y dejaria el postmaster vivo.
if [ "$(puerto_de "$TMP/arbol")" = "$p_arbol" ]; then
  echo '  ok   el puerto del worktree no cambia entre invocaciones'
else
  echo '  MAL  el puerto del worktree cambia entre corridas; --stop no lo hallaria'
  fallos=1
fi

echo
if [ "$fallos" -eq 0 ]; then
  echo 'Arnes de base-local: el candado aguanta y cada arbol tiene su puerto.'
else
  echo '::error::base-local puede corromper su datadir, o dos arboles se pelean un puerto.'
fi
exit "$fallos"
