#!/usr/bin/env bash
# Deja disponible la version fijada de actionlint e imprime su ruta (5.7.2).
#
# POR QUE EXISTE Y POR QUE ESTA PLATAFORMA
# El buscador de gitleaks solo trae el binario de linux_x64, asi que en un Mac sin
# gitleaks instalado esa mitad no corre. Para actionlint eso no sirve: el validador
# de workflows es de la Puerta 1 y la Puerta 1 se corre en la maquina antes de
# abrir el PR. Asi que se fijan los dos binarios, con su checksum cada uno.
#
# El checksum NO es opcional: descargar un binario y ejecutarlo sin verificarlo
# convierte una puerta de calidad en un vector de cadena de suministro.
# Los hashes salen del archivo de checksums de la release oficial.
set -euo pipefail

VERSION="1.7.12"
SHA_DARWIN_ARM64="aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f"
SHA_LINUX_AMD64="8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8"

if command -v actionlint >/dev/null 2>&1; then
  echo actionlint; exit 0
fi

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) PLAT="darwin_arm64"; SHA="$SHA_DARWIN_ARM64" ;;
  Linux/x86_64) PLAT="linux_amd64";  SHA="$SHA_LINUX_AMD64" ;;
  *) echo "::error::actionlint no esta instalado y no hay binario fijado para $(uname -s)/$(uname -m). Instalalo (brew install actionlint) para correr esta puerta aqui." >&2
     exit 1 ;;
esac

# Cache por version y plataforma, fuera del repo: dos llamadas en la misma corrida
# no descargan dos veces, y nada queda en el arbol de trabajo.
CACHE="${TMPDIR:-/tmp}/meridian-actionlint-${VERSION}-${PLAT}"
[ -x "$CACHE/actionlint" ] && { echo "$CACHE/actionlint"; exit 0; }

mkdir -p "$CACHE"
URL="https://github.com/rhysd/actionlint/releases/download/v${VERSION}/actionlint_${VERSION}_${PLAT}.tar.gz"
echo "→ descargando actionlint ${VERSION} (${PLAT})" >&2
curl -sSfL "$URL" -o "$CACHE/al.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  echo "${SHA}  $CACHE/al.tar.gz" | sha256sum -c - >/dev/null || { rm -rf "$CACHE"
    echo "::error::El checksum de actionlint no coincide. Se aborta." >&2; exit 1; }
else
  # macOS no trae sha256sum; shasum -a 256 es el equivalente.
  echo "${SHA}  $CACHE/al.tar.gz" | shasum -a 256 -c - >/dev/null || { rm -rf "$CACHE"
    echo "::error::El checksum de actionlint no coincide. Se aborta." >&2; exit 1; }
fi
tar -xzf "$CACHE/al.tar.gz" -C "$CACHE" actionlint
rm -f "$CACHE/al.tar.gz"
echo "$CACHE/actionlint"
