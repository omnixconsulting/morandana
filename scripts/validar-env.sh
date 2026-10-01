#!/usr/bin/env bash
# Contrato entre el codigo y .env.example (estandar Meridian, capa L0).
#
# POR QUE
# Una variable que el codigo lee y que nadie declaro se descubre en produccion,
# cuando algo responde 500 porque su llave llego vacia. Y una declarada que ya
# nadie lee es igual de mala en la otra direccion: manda a cargar en el proveedor
# algo que no sirve, y al siguiente lector le miente sobre lo que el proyecto
# necesita. Por eso la comparacion va en LOS DOS SENTIDOS.
#
# DOS FORMAS DE ACCESO, y hay que reconocer las dos: `env.X` y `env['X']`. Un
# validador que solo entienda la del punto pasa en verde sobre un repo entero que
# use corchetes, y un chequeo que no ve nada no falla: dice que todo cuadra. Es el
# mismo vicio que el `\b` de 5.7. Si aparece una forma que no sabe leer
# —desestructuracion, indice calculado— lo dice en voz alta en vez de ignorarla.
#
# Lo que NO comprueba: que el proveedor las tenga cargadas. Eso es revision
# manual y vive en revisiones-pendientes.md.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- lo unico que cambia por repo ---------------------------------------------
DIRS="src"          # donde vive el codigo que lee entorno
ACCESO="process\.env"      # process.env | import.meta.env | los dos
# -----------------------------------------------------------------------------

EJEMPLO=.env.example
[ -f "$EJEMPLO" ] || { echo "::error::Falta $EJEMPLO: el contrato de variables de entorno."; exit 1; }
# Presente en disco no basta: si .gitignore se lo traga, el contrato no se
# versiona, pasa en local y CI falla por archivo ausente. Un `.env*` sin
# `!.env.example` es justo eso.
git ls-files --error-unmatch "$EJEMPLO" >/dev/null 2>&1 || {
  echo "::error::$EJEMPLO existe pero no esta versionado. Revisa .gitignore: falta un !.env.example."; exit 1; }

# Se excluye a si mismo: si DIRS incluye scripts/, este archivo menciona
# `process.env` en sus comentarios y en su propia configuracion, y se marcaria
# como una lectura que no sabe leer. Mismo idioma que guardia-secretos.sh.
YO=':!scripts/validar-env.sh'
ARCHIVOS=$(git ls-files -- $DIRS "$YO" 2>/dev/null)
RE_OK="($ACCESO)(\.[A-Z_][A-Z0-9_]*|\[['\"][A-Z_][A-Z0-9_]*['\"]\])"

leidas=$(printf '%s\n' "$ARCHIVOS" | xargs grep -hoE "$RE_OK" 2>/dev/null \
  | sed -E "s/.*env\.?\[?['\"]?//; s/['\"]?\]?$//" | sort -u)
declaradas=$(grep -E '^[A-Z_][A-Z0-9_]*=' "$EJEMPLO" | sed 's/=.*//' | sort -u)
raras=$(printf '%s\n' "$ARCHIVOS" | xargs grep -nE "($ACCESO)" 2>/dev/null | grep -vE "$RE_OK")

fallos=0
if [ -n "$raras" ]; then
  echo "::error::Hay lecturas de entorno que este validador no sabe leer, asi que no puede garantizar el contrato."
  printf '%s\n' "$raras" | sed 's/^/    /'; fallos=1
fi
faltan=$(comm -23 <(printf '%s\n' "$leidas") <(printf '%s\n' "$declaradas"))
if [ -n "$faltan" ]; then
  echo "::error::El codigo lee variables que $EJEMPLO no declara."
  printf '%s\n' "$faltan" | sed 's/^/    falta declarar: /'; fallos=1
fi
sobran=$(comm -13 <(printf '%s\n' "$leidas") <(printf '%s\n' "$declaradas"))
if [ -n "$sobran" ]; then
  echo "::error::$EJEMPLO declara variables que nadie lee. Una que sobra tambien es deriva."
  printf '%s\n' "$sobran" | sed 's/^/    nadie la lee: /'; fallos=1
fi
# Un comentario alineado no es un valor. `=.+` casa el relleno de espacios y la
# almohadilla, asi que `VAR=        # nota` se denunciaba como valor inexistente.
# Hay que recortar el comentario en linea y los espacios ANTES de juzgar.
convalor=$(awk -F= '/^[A-Z_][A-Z0-9_]*=/ {
  v = substr($0, index($0, "=") + 1)
  sub(/[ \t]*#.*$/, "", v); gsub(/^[ \t]+|[ \t]+$/, "", v)
  if (length(v)) print $1
}' "$EJEMPLO")
if [ -n "$convalor" ]; then
  echo "::error::$EJEMPLO trae valores. Va vacio: es un contrato, no un almacen."
  printf '%s\n' "$convalor" | sed 's/^/    con valor: /'; fallos=1
fi
# En un repo que sirve estaticos, el archivo no trae valores pero publica la lista
# de proveedores y la arquitectura.
if [ -f .vercelignore ] && ! grep -qxF '.env.example' .vercelignore; then
  echo "::error::$EJEMPLO no esta excluido en .vercelignore, asi que se publica."; fallos=1
fi

[ "$fallos" -eq 0 ] && echo "Contrato de env: $(printf '%s\n' "$declaradas" | wc -l | tr -d ' ') variables, y coinciden en los dos sentidos."
exit "$fallos"
