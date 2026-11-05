#!/usr/bin/env bash
# Pasa los scripts de scripts/ por shellcheck, con trinquete.
#
# POR QUE EXISTE
# Las puertas de este repo revisan el codigo de la app, los contratos y los
# workflows. Lo que NADIE revisaba eran los `.sh` que implementan esas mismas
# puertas: el validador de workflows mira los bloques `run:` de los `.yml`, no
# los `.sh`. Medido el 15-oct-2026 en los diez repos del equipo: 358 hallazgos,
# ninguno visible para ninguna puerta.
#
# EL TRINQUETE LLEGO A CERO EL 5-NOV-2026
# Nacio con tope porque la deuda no cabia en un PR. Al leer los 21 caso por caso,
# 11 eran un defecto real y el resto se reparte entre arreglos y falsos positivos:
#
#   11 SC2164  `cd ... || exit 1` faltante en la primera linea de 11 scripts.
#              Con `set -uo pipefail` y sin `-e`, un `cd` que falla NO
#              detiene el script: el validador corre en el directorio de
#              quien lo invoco y sale en verde sin mirar nada. El mismo
#              defecto que `jerrymedrano` resolvio el 15-oct-2026 y el
#              landing el 5-nov; aqui llego por propagacion, no solo.
#
#   10 falsos  reales como aviso y falsos aqui: SC2016 (mensajes que imprimen
#              `$VAR` o acentos graves literales, y programas de `node -e`
#              cuyos `$` son de JavaScript), SC2012 (nombres que genera una
#              herramienta, sin espacios) y SC1007 (`VAR=` vacio para
#              quitarle una variable heredada al proceso hijo). Cada uno
#              queda anotado CON SU RAZON en su propia linea, no silenciado a
#              ciegas.
#
# Y las asignaciones con forma `A && B || C` de `arnes-secretos.sh` pasaron a
# if/else explicito: eran la unica fuente del SC2015 que el runner ve y esta
# maquina no.
#
# El numero no puede subir. En cero eso significa: cualquier hallazgo nuevo es
# rojo, y si es un falso positivo se anota con su razon, no se sube el tope.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

# El tope lo manda el conteo del CI, NO el local: shellcheck no reporta igual en
# las dos partes, y una diferencia de version pone el PR en rojo por la
# herramienta y no por el codigo. Si el CI imprime mas que este numero, ESE es el
# piso: subelo con el numero que imprima y deja escrito que hallazgo era.
TOPE=${TOPE:-0}

if ! command -v shellcheck >/dev/null 2>&1; then
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo '::error::shellcheck no esta instalado y esto corre en CI: la puerta de scripts/ no se ejecuto.'
    exit 1
  fi
  # Acentos graves de markdown dentro del aviso, literales a proposito.
  # shellcheck disable=SC2016
  echo '::notice::shellcheck no esta instalado: la puerta de scripts/ se salta. Instalalo con `brew install shellcheck` para que tu verde local valga lo mismo que el del CI.'
  exit 0
fi

# 1 · Directivas mal formadas. Sin trinquete y antes del conteo.
malas=$(grep -rnE '^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+' scripts/ 2>/dev/null \
  | grep -vE 'shellcheck[[:space:]]+(disable|enable|source|shell|external-sources)=' || true)
if [ -n "$malas" ]; then
  echo '::error::Hay un comentario que empieza con «shellcheck » y no es una directiva valida.'
  echo "$malas"
  echo '  Eso es SC1072/SC1073 y apaga el analisis del RESTO del archivo, sin fallar.'
  echo '  Ojo: un archivo cegado BAJA el conteo, asi que parece progreso contra el tope.'
  echo '  Reordena la frase para que «shellcheck» no sea la primera palabra tras el #.'
  exit 1
fi

# 2 · El conteo, contra el trinquete.
salida=$(shellcheck -f gcc scripts/*.sh 2>/dev/null || true)
actual=$(printf '%s' "$salida" | grep -c . || true)

echo "Scripts de shell: $actual hallazgo(s) de shellcheck (tope: $TOPE)"

if [ "$actual" -gt "$TOPE" ]; then
  printf '%s\n' "$salida" | head -20
  echo "::error::Los scripts empeoraron: $actual hallazgos contra un tope de $TOPE."
  echo '  Si alguno es un falso positivo, anotalo con «# shellcheck disable=SCxxxx»'
  echo '  y una linea arriba explicando por que. No lo silencies sin la razon.'
  exit 1
fi

if [ "$actual" -lt "$TOPE" ]; then
  echo "::notice::Bajaron los hallazgos ($actual < $TOPE). Baja TOPE en scripts/validar-scripts-shell.sh."
fi

exit 0
