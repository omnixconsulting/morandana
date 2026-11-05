#!/usr/bin/env bash
# Arnés del chequeo de puerto de `base-local.sh` (§5.7).
#
# Lo que este arnés existe para impedir: que el script vuelva a matar la base de
# otro repo. Antes se resolvía con `kill -9` sobre cualquier cosa que escuchara
# el puerto. La aserción que importa no es que el script falle: es que el
# proceso ajeno SIGA VIVO después.
#
# Desde el 15-oct-2026 cada repo tiene su puerto, así que encontrarlo ocupado ya
# no es lo normal —antes iban en pares y sí lo era—. El arnés sigue haciendo
# falta: un puerto propio hace el choque raro, no imposible, y es justo cuando
# es raro cuando nadie vuelve a probar a mano que el script se niega en vez de
# matar.
#
# Levanta su propio Postgres en un puerto y un datadir temporales. No toca el
# datadir del repo ni el puerto de ningún otro.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
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
  # shellcheck disable=SC2012  # rutas fijas del sistema: el glob ya las expande y hace falta ordenarlas por version
  BIN="$(ls -d /usr/lib/postgresql/*/bin 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "${BIN:-}" ] || [ ! -x "$BIN/pg_ctl" ]; then
  echo "::error::no encuentro pg_ctl; el arnés de base-local no puede medir nada" >&2
  exit 1
fi

TMP="$(mktemp -d)"
AJENO="$TMP/ajeno"
PUERTO_PRUEBA=55995
# Los casos de `--stop` (abajo, 5) levantan su propio servidor y necesitan un
# puerto que NO sea el de los casos de la guardia: el caso 4 deja un postmaster
# propio en PUERTO_PRUEBA, y arrancar otro ahi fallaria por puerto ocupado.
#
# Y TAMPOCO PUEDE SER EL DE OTRO REPO. Este arnes vive en seis repos, cada uno
# con su PUERTO_PRUEBA en la banda 55994-55999 (map 55999, medicarmen 55998,
# shikomi 55997, mise 55996, morandana 55995, crm 55994). El primer intento de
# este arnes, el 5-nov-2026, puso aqui 55998, que es el PUERTO_PRUEBA de
# medicarmen: dos arneses corriendo a la vez --dos sesiones, o dos repos en una
# puerta encadenada-- se habrian peleado el puerto y el que perdiera habria
# fallado por «no pudo levantar el Postgres del caso --stop», que no dice nada
# del defecto que mide. Los PUERTO_STOP van en 55984-55989, debajo de esa banda
# y por encima de la de los arboles de trabajo (55500-55899), que la calcula
# `puerto_del_arbol`.
PUERTO_STOP=55985
PARA="$TMP/para"

# Limpia TODO lo que quede en el puerto de prueba cuyo datadir esté bajo $TMP,
# no solo el Postgres que este arnés levantó. Hace falta: un `base-local.sh`
# roto puede arrancar el suyo —el código viejo mataba al ajeno y se quedaba con
# el puerto—, y ese huérfano trabaría la siguiente corrida del arnés.
limpiar() {
  "$BIN/pg_ctl" -D "$AJENO" -m fast stop >/dev/null 2>&1 || true
  "$BIN/pg_ctl" -D "$PARA" -m fast stop >/dev/null 2>&1 || true
  local p pto
  for pto in "$PUERTO_PRUEBA" "$PUERTO_STOP"; do
    while IFS= read -r p; do
      [ -n "$p" ] || continue
      case "$(ps -o command= -p "$p" 2>/dev/null)" in
        *"$TMP"*) kill -TERM "$p" 2>/dev/null || true ;;
      esac
    done <<< "$(lsof -tiTCP:"$pto" -sTCP:LISTEN 2>/dev/null)"
  done
  sleep 1
  rm -rf "$TMP"
}
trap limpiar EXIT

fallos=0
# El total se cuenta, no se escribe: el ultimo caso de `--stop` no se puede
# plantar en una maquina con postgresql@17 de homebrew, y un numero fijo
# obligaria a elegir entre un rojo falso alla o un verde falso aca.
verdes=0
ok()  { echo "  ✓ $1"; verdes=$((verdes+1)); }
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
if [ "$codigo" -ne 0 ]; then
  ok "clon nuevo con el puerto ocupado: el script se niega"
else
  mal "clon nuevo con el puerto ocupado: el script NO se negó"
fi
if grep -qF "no es el de este repo" <<<"$salida"; then
  ok "el mensaje dice que el puerto es de otro repo"
else
  mal "el mensaje no explica de quién es el puerto"
fi
if grep -qF -- "$AJENO" <<<"$salida"; then
  ok "el mensaje nombra el datadir ajeno"
else
  mal "el mensaje no nombra el datadir ajeno"
fi

# LA aserción: el ajeno sigue vivo.
if kill -0 "$PID_AJENO" 2>/dev/null; then
  ok "el Postgres ajeno SIGUE VIVO (la regresión que esto impide)"
else
  mal "el Postgres ajeno MURIÓ: volvió la regresión del kill -9"
fi

# --- 2. Pidfile rancio: nuestro datadir existe, su PID ya no escucha ---------
RANCIO="$TMP/rancio"
mkdir -p "$RANCIO/base"
echo 999999 > "$RANCIO/postmaster.pid"
salida="$(corre "$RANCIO")"; codigo=$?
# Mide el MENSAJE, no solo el código: con el `kill -9` viejo este caso también
# salía distinto de cero, pero por «could not start server» después de haber
# matado al ajeno. El código de salida no distingue las dos cosas.
if { [ "$codigo" -ne 0 ] && grep -qF "no es el de este repo" <<<"$salida"; }; then
  ok "pidfile rancio y puerto ajeno: se niega explicándolo, no con «could not start server»"
else
  mal "pidfile rancio: no se negó con el mensaje del chequeo de puerto"
fi
if kill -0 "$PID_AJENO" 2>/dev/null; then
  ok "el ajeno sigue vivo también en el caso del pidfile rancio"
else
  mal "el ajeno murió en el caso del pidfile rancio"
fi

# --- 3. Sin falso positivo: el postmaster del puerto es NUESTRO -------------
# Mismo datadir que el "ajeno": desde el punto de vista del script, es suyo.
salida="$(corre "$AJENO")"
if grep -qF "no es el de este repo" <<<"$salida"; then
  mal "falso positivo: se negó aunque el postmaster del puerto es suyo"
else
  ok "no se niega cuando el postmaster del puerto es de su propio datadir"
fi

# --- 4. Puerto libre: tampoco se niega --------------------------------------
"$BIN/pg_ctl" -D "$AJENO" -m fast stop >/dev/null 2>&1
sleep 1
salida="$(corre "$TMP/libre")"
if grep -qF "no es el de este repo" <<<"$salida"; then
  mal "falso positivo: se negó con el puerto libre"
else
  ok "con el puerto libre no se niega"
fi

# --- 5. `--stop` no miente ---------------------------------------------------
#
# El defecto que estos casos plantan: hasta el 5-nov-2026 `--stop` imprimía
# «servidor detenido» SIN CONDICIÓN, con el `pg_ctl stop` silenciado por
# `>/dev/null 2>&1 || true`. Decía lo mismo apagando, sin nada que apagar y con
# pg_ctl fallando, así que el mensaje no era evidencia de nada. Se detectó al
# borrar un árbol de trabajo cuyo postmaster seguía vivo después del «detenido».
echo
echo "  (--stop)"
paraya() { PGDATA="$PARA" PGPUERTO="$PUERTO_STOP" bash "$SCRIPT" --stop 2>&1; }

# 5a) Sin nada arriba no puede decir que detuvo algo. El datadir ni existe.
salida="$(paraya)"; codigo=$?
if [ "$codigo" -eq 0 ] && ! grep -qF "servidor detenido" <<<"$salida"; then
  ok "sin servidor arriba, --stop no canta «servidor detenido»"
else
  mal "sin servidor arriba, --stop canta «servidor detenido» igual (código $codigo)"
fi

# 5b) Con un servidor NUESTRO arriba: lo apaga de verdad, y lo dice.
#     Se levanta con pg_ctl directo y no con base-local.sh, para que el caso mida
#     el apagado y no el arranque.
LC_ALL=C "$BIN/initdb" -D "$PARA" -U postgres -A trust -E UTF8 >/dev/null 2>&1
LC_ALL=C "$BIN/pg_ctl" -D "$PARA" \
  -o "-p $PUERTO_STOP -c listen_addresses=localhost -c unix_socket_directories=/tmp" \
  -l "$PARA/server.log" start >/dev/null 2>&1
sleep 2
PID_PARA="$(head -1 "$PARA/postmaster.pid" 2>/dev/null)"
if [ -z "$PID_PARA" ] || ! kill -0 "$PID_PARA" 2>/dev/null; then
  echo "::error::el arnés no pudo levantar el Postgres del caso --stop; no midió el apagado" >&2
  exit 1
fi
salida="$(paraya)"; codigo=$?
if [ "$codigo" -eq 0 ] && grep -qF "servidor detenido" <<<"$salida"; then
  ok "con un servidor propio arriba, --stop dice que lo detuvo"
else
  mal "con un servidor propio arriba, --stop no reportó el apagado (código $codigo)"
fi
# LA aserción del caso: el postmaster ya no está. Se comprueba contra el proceso,
# no contra el mensaje, que es justo lo que no se podía creer.
#
# Y SE ESPERA, PORQUE MIRAR UNA VEZ ERA UNA VENTANA DE CARRERA
# `pg_ctl -m fast stop` da por terminado el apagado cuando desaparece el pidfile,
# y el postmaster puede tardar un instante mas en salir del todo. La primera
# version de este caso miraba `kill -0` UNA sola vez, inmediatamente: en una Mac
# nunca se veia, y en un runner cargado si. Lo atrapo el CI de shikomi el
# 5-nov-2026 --corrida 42106340879, «el postmaster SIGUE VIVO (PID 3681)»-- con
# el mismo arnes en verde en los otros cinco repos. Un arnes que pasa en local y
# falla en CI es una ventana de carrera, no un flake.
#
# La espera es acotada y NO debilita la asercion: el caso 5d, donde el servidor
# se queda arriba de verdad porque pg_ctl falla, sigue fallando aqui porque ahi
# el proceso no se va nunca.
murio() {
  local pid="$1" intentos=50          # 50 x 0.2 s = hasta 10 s
  while [ "$intentos" -gt 0 ]; do
    kill -0 "$pid" 2>/dev/null || return 0
    sleep 0.2
    intentos=$((intentos - 1))
  done
  return 1
}
if murio "$PID_PARA"; then
  ok "y el postmaster murió de verdad (PID $PID_PARA)"
else
  mal "el postmaster SIGUE VIVO 10 s después del «servidor detenido» (PID $PID_PARA)"
fi

# 5c) Repetirlo sobre el mismo datadir, ya apagado: tampoco puede decir que apagó.
salida="$(paraya)"; codigo=$?
if [ "$codigo" -eq 0 ] && ! grep -qF "servidor detenido" <<<"$salida"; then
  ok "repetido sobre un datadir ya apagado, --stop no vuelve a cantar el apagado"
else
  mal "repetido sobre un datadir ya apagado, --stop dice que detuvo algo (código $codigo)"
fi

# 5d) EL CASO PLANTADO: el servidor está arriba y pg_ctl falla. El mensaje tiene
#     que decir la verdad --que sigue arriba-- y el código salir distinto de cero.
#
#     Se planta con un `pg_ctl` de pega primero en el PATH. Eso solo funciona si
#     base-local.sh resuelve su binario por PATH; en una máquina con
#     postgresql@17 de homebrew lo prefiere por ruta absoluta y el stub no entra.
#     Entonces este caso NO se mide, y se dice: un verde aquí sería falso.
if [ -x /opt/homebrew/opt/postgresql@17/bin/pg_ctl ]; then
  echo "  ·  (5d sin medir: hay postgresql@17 en /opt/homebrew, que base-local.sh"
  echo "      prefiere por ruta absoluta, así que el pg_ctl de pega no entra)"
else
  LC_ALL=C "$BIN/pg_ctl" -D "$PARA" \
    -o "-p $PUERTO_STOP -c listen_addresses=localhost -c unix_socket_directories=/tmp" \
    -l "$PARA/server.log" start >/dev/null 2>&1
  sleep 2
  PID_TERCO="$(head -1 "$PARA/postmaster.pid" 2>/dev/null)"
  STUB="$TMP/stub"
  mkdir -p "$STUB"
  printf '%s\n' '#!/bin/sh' 'echo "pg_ctl de pega: no voy a parar nada" >&2' 'exit 1' > "$STUB/pg_ctl"
  chmod +x "$STUB/pg_ctl"
  salida="$(PATH="$STUB:$PATH" PGDATA="$PARA" PGPUERTO="$PUERTO_STOP" bash "$SCRIPT" --stop 2>&1)"; codigo=$?
  if [ "$codigo" -ne 0 ] && ! grep -qF "servidor detenido" <<<"$salida"; then
    ok "con pg_ctl fallando, --stop falla y NO dice «servidor detenido»"
  else
    mal "con pg_ctl fallando, --stop salió en verde (código $codigo)"
  fi
  if grep -qF "SIGUE ARRIBA" <<<"$salida"; then
    ok "y el mensaje dice que el servidor sigue arriba, que es la verdad"
  else
    mal "el mensaje no dice que el servidor siguió arriba"
  fi
  if [ -n "$PID_TERCO" ] && kill -0 "$PID_TERCO" 2>/dev/null; then
    ok "el servidor sigue vivo: --stop no lo mató por su cuenta al ver que pg_ctl falló"
  else
    mal "el servidor murió con pg_ctl fallando: algo lo está matando a mano"
  fi
  "$BIN/pg_ctl" -D "$PARA" -m fast stop >/dev/null 2>&1 || true
fi

echo
if [ "$fallos" -gt 0 ]; then
  echo "::error::Arnés de base-local: $fallos aserción(es) en rojo."
  exit 1
fi
echo "Arnés de base-local: las $verdes aserciones en verde."
