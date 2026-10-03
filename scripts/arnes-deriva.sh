#!/usr/bin/env bash
# Arnes de `deriva-produccion.sh`: le planta estados de produccion y exige que
# los reconozca (§5.7, «romperla a proposito»).
#
# POR QUE EXISTE
# El detector dice «ninguna» cuando todo esta bien, que es indistinguible de un
# detector roto. Si su parseo deja de funcionar, no falla: calla. Y lo que
# vigila son migraciones de seguridad sin aplicar.
#
# No toca ninguna base: le pasa archivos con la forma de la respuesta real.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fixture=$(mktemp -d); trap 'rm -rf "$fixture"' EXIT
fallos=0; casos=0

probar() {
  local nombre=$1 esperado=$2 marcador=$3 json=$4
  casos=$((casos + 1))
  printf '%s' "$json" > "$fixture/estado.json"
  local salida codigo
  salida=$(./scripts/deriva-produccion.sh "$fixture/estado.json" 2>&1); codigo=$?
  if [ "$codigo" = "$esperado" ] && printf '%s' "$salida" | grep -qF -e "$marcador"; then
    printf '  ok   %-34s exit %s\n' "$nombre" "$codigo"
  else
    printf '  MAL  %-34s exit %s (esperado %s), sin «%s»\n' "$nombre" "$codigo" "$esperado" "$marcador"
    printf '%s\n' "$salida" | sed 's/^/         /'
    fallos=1
  fi
}

echo 'Arnes del detector de deriva:'

probar "todo aplicado" 0 "Deriva de produccion: ninguna" \
  '{"migrations":[{"local":"20260101000000","remote":"20260101000000"},{"local":"20260102000000","remote":"20260102000000"}]}'

probar "una sin aplicar" 1 "SIN APLICAR en produccion: 20260922120000" \
  '{"migrations":[{"local":"20260101000000","remote":"20260101000000"},{"local":"20260922120000","remote":""}]}'

probar "la ultima sin aplicar, que es lo comun" 1 "20260922120000" \
  '{"migrations":[{"local":"20260101000000","remote":"20260101000000"},{"local":"20260102000000","remote":"20260102000000"},{"local":"20260922120000","remote":""}]}'

probar "varias sin aplicar" 1 "20260922000004 20260922000005" \
  '{"migrations":[{"local":"20260922000004","remote":""},{"local":"20260922000005","remote":""}]}'

probar "produccion con algo que el repo no tiene" 0 "NO estan en el repo" \
  '{"migrations":[{"local":"20260101000000","remote":"20260101000000"},{"local":"","remote":"20260815000000"}]}'

probar "las dos cosas a la vez" 1 "SIN APLICAR" \
  '{"migrations":[{"local":"","remote":"20260815000000"},{"local":"20260922120000","remote":""}]}'

probar "sin ninguna migracion" 0 "0 migraciones" \
  '{"migrations":[]}'

echo
if [ "$fallos" -eq 0 ]; then
  echo "Arnes del detector de deriva: $casos caso(s), todos como se esperaba."
else
  echo '::error::El detector de deriva esta ciego a algo que deberia ver.'
fi
exit "$fallos"
