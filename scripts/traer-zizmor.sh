#!/usr/bin/env bash
# Deja disponible la version fijada de zizmor e imprime su ruta (1.30.1).
#
# QUE ES Y QUE AGREGA SOBRE ACTIONLINT
# actionlint revisa que el workflow sea VALIDO; zizmor revisa que sea SEGURO.
# Son redes distintas: actionlint no dice nada de un token que se persiste en el
# arbol, de una expresion `${{ }}` interpolada dentro de un `run:` ni de un
# `pull_request_target` que hace checkout del codigo del PR.
#
# POR QUE SE FIJAN LOS DOS BINARIOS
# Mismo argumento que actionlint: el validador de workflows es de la Puerta 1, y
# la Puerta 1 se corre en la maquina antes de abrir el PR. Un buscador que solo
# trae el binario de Linux deja esa comprobacion sin correr en un Mac.
#
# DE DONDE SALEN LOS HASHES
# La release de zizmor NO publica archivo de checksums, asi que estos se
# calcularon aqui. Lo que los hace confiables no es haberlos calculado, sino que
# los dos binarios se verificaron antes con la atestacion de procedencia de
# GitHub:
#
#   gh attestation verify zizmor-aarch64-apple-darwin.tar.gz --repo zizmorcore/zizmor
#
# que confirma que los construyo `release-binaries.yml` del propio repo en el tag
# v1.30.1. Fijar el hash convierte eso en «este artefacto exacto» para siempre.
# Al subir de version hay que repetir las dos cosas: verificar la atestacion y
# recalcular.
#
# El checksum NO es opcional: descargar un binario y ejecutarlo sin verificarlo
# convierte una puerta de calidad en un vector de cadena de suministro.
set -euo pipefail

VERSION="1.30.1"
SHA_DARWIN_ARM64="e28d22b087f9ebb8d99da6e740d348c930f559961c7c3f12badda54f882195a2"
SHA_LINUX_AMD64="e65324f4430c2717591937edcec90ccbefaf14c174f8ec9415e03ca875b46e1a"

if command -v zizmor >/dev/null 2>&1; then
  echo zizmor; exit 0
fi

case "$(uname -s)/$(uname -m)" in
  Darwin/arm64) TRIPLE="aarch64-apple-darwin";      SHA="$SHA_DARWIN_ARM64" ;;
  Linux/x86_64) TRIPLE="x86_64-unknown-linux-gnu";  SHA="$SHA_LINUX_AMD64" ;;
  *) echo "::error::zizmor no esta instalado y no hay binario fijado para $(uname -s)/$(uname -m). Instalalo (brew install zizmor) para correr esta puerta aqui." >&2
     exit 1 ;;
esac

CACHE="${TMPDIR:-/tmp}/meridian-zizmor-${VERSION}-${TRIPLE}"
[ -x "$CACHE/zizmor" ] && { echo "$CACHE/zizmor"; exit 0; }

mkdir -p "$CACHE"
URL="https://github.com/zizmorcore/zizmor/releases/download/v${VERSION}/zizmor-${TRIPLE}.tar.gz"
echo "→ descargando zizmor ${VERSION} (${TRIPLE})" >&2
curl -sSfL "$URL" -o "$CACHE/z.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  echo "${SHA}  $CACHE/z.tar.gz" | sha256sum -c - >/dev/null || { rm -rf "$CACHE"
    echo "::error::El checksum de zizmor no coincide. Se aborta." >&2; exit 1; }
else
  # macOS no trae sha256sum; shasum -a 256 es el equivalente.
  echo "${SHA}  $CACHE/z.tar.gz" | shasum -a 256 -c - >/dev/null || { rm -rf "$CACHE"
    echo "::error::El checksum de zizmor no coincide. Se aborta." >&2; exit 1; }
fi
tar -xzf "$CACHE/z.tar.gz" -C "$CACHE" zizmor
rm -f "$CACHE/z.tar.gz"
echo "$CACHE/zizmor"
