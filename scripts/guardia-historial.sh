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

VERSION="8.30.1"
SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"

if command -v gitleaks >/dev/null 2>&1; then
  GL=gitleaks
else
  # En CI no viene instalado. Se descarga la versión fijada y se verifica el
  # checksum: sin eso, esta guardia sería un vector de cadena de suministro
  # dentro de la guardia de seguridad.
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  URL="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_x64.tar.gz"
  echo "→ descargando gitleaks ${VERSION}"
  curl -sSfL "$URL" -o "$TMP/gl.tar.gz"
  echo "${SHA256}  $TMP/gl.tar.gz" | sha256sum -c - >/dev/null || {
    echo "::error::El checksum de gitleaks no coincide. Se aborta." >&2; exit 1; }
  tar -xzf "$TMP/gl.tar.gz" -C "$TMP" gitleaks
  GL="$TMP/gitleaks"
fi

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
