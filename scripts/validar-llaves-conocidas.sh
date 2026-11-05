#!/usr/bin/env bash
# El contrato de llaves conocidas contra .gitleaks.toml, en los DOS sentidos.
#
# POR QUE
# El conjunto de tipos que el portafolio dice reconocer vive hoy en dos
# dialectos que no se pueden compartir: ERE POSIX en `contracts/llaves-conocidas.txt`
# —que leen la guardia y el arnes— y RE2 en `.gitleaks.toml`, que consume un
# binario. `git grep -E` no soporta `\b` y no falla al encontrarlo: devuelve cero
# coincidencias, asi que copiar un patron de un lado al otro apaga una de las dos
# busquedas en silencio.
#
# Lo que SI se puede atar es la lista de TIPOS. Este validador exige que cada
# prefijo del contrato tenga su regla en el TOML, y que cada regla `meridian-*`
# del TOML tenga su fila en el contrato. Conjunto exacto, como el de hooks, el de
# scripts de instalacion y el de cabeceras: lo que hace dano es lo que nadie
# enumero.
#
# Lo que NO hace: comparar los patrones entre si. Son dialectos distintos a
# proposito, y el que comprueba que ambos de verdad atrapan cada tipo es
# `arnes-secretos.sh`, plantando una llave de cada uno.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

CONTRATO=contracts/llaves-conocidas.txt
TOML=.gitleaks.toml
fallos=0

for f in "$CONTRATO" "$TOML"; do
  [ -f "$f" ] || { echo "::error::falta $f."; exit 1; }
done

# Prefijos que el contrato declara.
prefijos=$(grep -v '^#' "$CONTRATO" | awk -F'\t' 'NF>=3 {print $2}' | sort -u)
[ -n "$prefijos" ] || { echo "::error::$CONTRATO no declara ningun prefijo."; exit 1; }

# Un prefijo esta cubierto si aparece dentro del regex de alguna regla del TOML.
# Se busca literal: el prefijo es texto plano en los dos dialectos, y es justo la
# parte que NO cambia entre ERE y RE2.
faltan=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  grep -qF -- "$p" "$TOML" || faltan="$faltan $p"
done <<< "$prefijos"

if [ -n "$faltan" ]; then
  echo "::error::$TOML no cubre estos prefijos del contrato:$faltan"
  echo "  Cada fila del contrato necesita su regla en el TOML. gitleaks se salta"
  echo "  ramas de una alternacion, asi que va UNA regla por prefijo."
  fallos=1
fi

# Y al reves: una regla nuestra en el TOML que el contrato no declara significa
# que la guardia del arbol no la busca, y que el arnes no la planta.
sobran=""
while IFS= read -r id; do
  [ -n "$id" ] || continue
  # El prefijo de esa regla tiene que estar en el contrato. Se busca por el regex
  # de la regla, no por su id: los ids no siguen el nombre del tipo.
  rx=$(awk -v id="$id" '
    $0 ~ "id = \"" id "\"" {dentro=1}
    dentro && /^regex/ {print; exit}
  ' "$TOML")
  cubierta=0
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    case "$rx" in *"$p"*) cubierta=1; break ;; esac
  done <<< "$prefijos"
  [ "$cubierta" = 0 ] && sobran="$sobran $id"
done <<< "$(grep -oE '^id = "meridian-[a-z0-9-]+"' "$TOML" | sed 's/^id = "//;s/"$//')"

if [ -n "$sobran" ]; then
  echo "::error::$TOML tiene reglas que el contrato no declara:$sobran"
  echo "  Si el portafolio de verdad reconoce ese tipo, va su fila en el contrato"
  echo "  para que la guardia del arbol lo busque y el arnes lo plante."
  fallos=1
fi

if [ "$fallos" -ne 0 ]; then exit 1; fi
echo "Contrato de llaves: $(printf '%s\n' "$prefijos" | wc -l | tr -d ' ') prefijos, todos con regla en $TOML y sin reglas de mas."
