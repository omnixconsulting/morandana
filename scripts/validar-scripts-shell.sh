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
# POR QUE CON TRINQUETE Y NO EN CERO
# Aqui la deuda no cabe en un PR: varios hallazgos son SC2015 (`A && B || C`),
# que cambia el flujo de control y pide leerse caso por caso. Apagar el chequeo
# lo vuelve decorativo; exigir cero bloquea el repo. El numero no puede subir, y
# cada limpieza baja el tope aqui, en el mismo PR. Mismo trato que el lint.
#
# LA REVISION 1 NO LLEVA TRINQUETE, Y ES LA QUE MAS IMPORTA
# Un comentario que EMPIEZA con `shellcheck ` y no trae `clave=valor` se lee como
# directiva, es error duro (SC1072/SC1073) y shellcheck DEJA DE ANALIZAR EL RESTO
# DEL ARCHIVO. Con un trinquete eso es peor que sin el: un archivo cegado hace
# BAJAR el conteo, asi que parece progreso e invita a bajar el tope. Por eso va
# primero y falla siempre.
#
# Paso de verdad: en `mise`, el comentario que ADVERTIA de esta trampa quedo con
# la palabra al inicio al partirse por el ancho de linea, y cegaba el validador
# de workflows de la linea 133 en adelante, tapando dos hallazgos reales.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

TOPE=${TOPE:-43}

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
