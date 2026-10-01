#!/usr/bin/env bash
# Deja disponible la version fijada de gitleaks e imprime su ruta (estandar
# Meridian 5.7). Una sola implementacion: la usan guardia-historial.sh y
# arnes-secretos.sh.
#
# POR QUE EXISTE
# La descarga con checksum vivia dentro de guardia-historial.sh, en un temporal
# que se borraba al salir. El arnes necesita el mismo binario, y copiar el bloque
# habria dejado dos sitios donde fijar la version y verificar el hash: uno se
# queda atras, y aqui quedarse atras significa correr un binario sin comprobar.
#
# El checksum NO es opcional: sin el, la guardia de secretos seria ella misma un
# vector de cadena de suministro.
#
# Imprime la ruta por stdout y el progreso por stderr, para que el llamador pueda
# hacer GL=$(./scripts/traer-gitleaks.sh).
set -euo pipefail

VERSION="8.30.1"
SHA256="551f6fc83ea457d62a0d98237cbad105af8d557003051f41f3e7ca7b3f2470eb"

if command -v gitleaks >/dev/null 2>&1; then
  echo gitleaks; exit 0
fi

# Cache por version, fuera del repo: dos llamadas en la misma corrida de CI no
# descargan dos veces, y nada queda en el arbol de trabajo.
CACHE="${TMPDIR:-/tmp}/meridian-gitleaks-${VERSION}"
if [ -x "$CACHE/gitleaks" ]; then
  echo "$CACHE/gitleaks"; exit 0
fi

# El binario fijado es de linux_x64, que es lo que corre el runner. En un Mac sin
# gitleaks instalado se dice y se falla, en vez de bajar un binario de otra
# plataforma y que el error aparezca disfrazado de «sin hallazgos».
case "$(uname -s)" in
  Linux) ;;
  *) echo "::error::gitleaks no esta instalado y la version fijada es de linux_x64. Instalalo (brew install gitleaks) para correr esto aqui." >&2
     exit 1 ;;
esac

mkdir -p "$CACHE"
URL="https://github.com/gitleaks/gitleaks/releases/download/v${VERSION}/gitleaks_${VERSION}_linux_x64.tar.gz"
echo "→ descargando gitleaks ${VERSION}" >&2
curl -sSfL "$URL" -o "$CACHE/gl.tar.gz"
echo "${SHA256}  $CACHE/gl.tar.gz" | sha256sum -c - >/dev/null || {
  rm -rf "$CACHE"
  echo "::error::El checksum de gitleaks no coincide. Se aborta." >&2; exit 1; }
tar -xzf "$CACHE/gl.tar.gz" -C "$CACHE" gitleaks
rm -f "$CACHE/gl.tar.gz"
echo "$CACHE/gitleaks"
