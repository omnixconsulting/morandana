#!/usr/bin/env bash
# Guardia de historial (estándar Meridian, capa L0).
#
# `guardia-secretos.sh` mira el ÁRBOL DE TRABAJO. Esta mira los COMMITS.
#
# La diferencia importa por un caso concreto: un secreto que entra en un commit
# y se borra en el siguiente del mismo PR. El árbol final queda limpio, la
# guardia normal pasa, y el secreto queda en los objetos de git para siempre.
# Un historial no se puede desrevelar, y que un repo sea privado hoy es una
# decisión reversible.
#
#   ./scripts/guardia-historial.sh                  # todo el historial
#   ./scripts/guardia-historial.sh base..head       # solo ese rango
#
# Las reglas están en `.gitleaks.toml`: las de gitleaks más los prefijos de este
# portafolio (sb_secret_, sk-ant-, re_, AKIA, shp*_, cal_live_). Se verificó que
# las reglas por omisión de gitleaks atrapan solo 2 de esos 7 patrones, así que
# la extensión no es decorativa.

set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# La version fijada y su checksum viven en scripts/traer-gitleaks.sh, que es la
# unica implementacion: el arnes de llaves plantadas necesita el mismo binario, y
# dos copias serian dos sitios donde fijar la version y verificar el hash.
GL="$(./scripts/traer-gitleaks.sh)"

RANGO="${1:-}"
if [ -n "$RANGO" ]; then
  echo "→ revisando el rango $RANGO"
  set -- --log-opts "$RANGO"
else
  echo "→ revisando el historial completo"
  set --
fi

# --redact es obligatorio: sin él, un hallazgo imprimiría el secreto en el log
# de CI, que es público para quien tenga acceso al repo y queda archivado.
if "$GL" git . -c .gitleaks.toml --redact --no-banner "$@"; then
  echo 'Guardia de historial: sin hallazgos.'
else
  echo '::error::Secreto en el historial. No basta con borrarlo: hay que ROTARLO.'
  exit 1
fi
