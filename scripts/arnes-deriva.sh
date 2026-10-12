#!/usr/bin/env bash
# Arnes de `deriva-produccion.sh`: le planta estados de produccion y exige que
# los reconozca (§5.7, «romperla a proposito»).
#
# POR QUE EXISTE
# El detector dice «ninguna» cuando todo esta bien, que es indistinguible de un
# detector roto. Si su parseo deja de funcionar, no falla: calla. Y lo que
# vigila son migraciones de seguridad sin aplicar.
#
# No toca ninguna base. Dos mitades, y la segunda se agrego el 8-oct-2026:
#   1. PARSEO: se le pasan archivos con la forma de la respuesta real.
#   2. LA LLAMADA AL CLI: se pone un `supabase` falso en el PATH. Esta mitad no
#      existia, y por eso el arnes seguia en verde con el detector inservible:
#      el CLI 2.11x dejo de emitir JSON por omision, el detector dejo de poder
#      leer produccion, y los siete casos de parseo no tocaban esa linea.
#      Un arnes que cubre todo menos la linea que se rompe no es un arnes.
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

# --- 2) la llamada al CLI, con un doble en el PATH ---------------------------
#
# El detector solo puede leer produccion si invoca al CLI con la bandera
# correcta. Aqui no hay produccion: hay un `supabase` falso que responde segun
# lo que le pidan, y lo que se afirma es que el detector pida bien.
echo
echo 'Arnes de la llamada al CLI:'

falso=$(mktemp -d); trap 'rm -rf "$fixture" "$falso"' EXIT

# $1 = nombre, $2 = exit esperado, $3 = marcador, $4 = cuerpo del doble
probar_cli() {
  local nombre=$1 esperado=$2 marcador=$3 cuerpo=$4
  casos=$((casos + 1))
  printf '#!/usr/bin/env bash\n%s\n' "$cuerpo" > "$falso/supabase"
  chmod +x "$falso/supabase"
  # El detector exige estar enlazado antes de llamar al CLI.
  mkdir -p supabase/.temp
  local creado=0
  [ -f supabase/.temp/project-ref ] || { echo arnes > supabase/.temp/project-ref; creado=1; }
  local salida codigo
  salida=$(PATH="$falso:$PATH" ./scripts/deriva-produccion.sh 2>&1); codigo=$?
  [ "$creado" = 1 ] && rm -f supabase/.temp/project-ref
  if [ "$codigo" = "$esperado" ] && printf '%s' "$salida" | grep -qF -e "$marcador"; then
    printf '  ok   %-34s exit %s\n' "$nombre" "$codigo"
  else
    printf '  MAL  %-34s exit %s (esperado %s), sin «%s»\n' "$nombre" "$codigo" "$esperado" "$marcador"
    printf '%s\n' "$salida" | sed 's/^/         /'
    fallos=1
  fi
}

# EL CASO QUE MOTIVO ESTA MITAD: el CLI imprime una tabla, como hace desde la
# 2.11x cuando no se le pide JSON. El detector tiene que FALLAR, no callar.
probar_cli 'el CLI contesta una tabla' 1 'El chequeo NO corrio' \
  'echo "   Local | Remote"; echo "   20260101000000 | 20260101000000"'

# Y tiene que decir QUE paso, no solo que algo paso.
probar_cli 'y dice que no era el JSON esperado' 1 'no es el JSON esperado' \
  'echo "   Local | Remote"'

# La bandera: el doble solo devuelve JSON si se la pasan. Si el detector dejara
# de mandarla, este caso se pone rojo.
probar_cli 'el detector pide --output-format json' 0 'Deriva de produccion: ninguna' \
  'case "$*" in *--output-format*json*) echo "{\"migrations\":[{\"local\":\"20260101000000\",\"remote\":\"20260101000000\"}]}" ;; *) echo "   Local | Remote" ;; esac'

# Un CLI que muere: tampoco puede pasar por «sin deriva», y el stderr se muestra.
probar_cli 'el CLI falla y se ve su stderr' 1 'stderr del CLI' \
  'echo "no estas enlazado" >&2; exit 1'

echo
if [ "$fallos" -eq 0 ]; then
  echo "Arnes del detector de deriva: $casos caso(s), todos como se esperaba."
else
  echo '::error::El detector de deriva esta ciego a algo que deberia ver.'
fi
exit "$fallos"
