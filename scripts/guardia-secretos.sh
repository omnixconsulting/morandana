#!/usr/bin/env bash
# Guardia de secretos (estándar Meridian, capa L0).
#
# En Next, todo lo que empieza con NEXT_PUBLIC_ se inyecta en el bundle del
# navegador, y un componente con "use client" se envía completo al cliente.
# Revisa únicamente archivos versionados —lo que no está en git no se despliega.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

fallos=0
yo=':!scripts/guardia-secretos.sh'

# 1. Valores de llaves secretas en cualquier archivo versionado. Los patrones
#    exigen longitud de llave real para no marcar menciones en comentarios.
#    LA LISTA NO VIVE AQUI. Sale de contracts/llaves-conocidas.txt, la misma
#    tabla que lee el arnes y contra la que se valida .gitleaks.toml. Vivia
#    escrita a mano en los TRES lugares y se bifurco: a `map` le faltaron
#    `shpca_` y `shpsa_` desde el 30-sep-2026 hasta el 4-nov, cinco semanas en
#    las que su guardia del arbol no veia dos tipos que su propio gitleaks si.
#    Ninguna puerta lo detecto; lo encontro alguien comparando a mano.
#
#    Los patrones de esa tabla son ERE POSIX y NO los RE2 del TOML, a proposito:
#    `git grep -E` no soporta `\b` y **no falla** al encontrarlo, devuelve cero
#    coincidencias. La regla de Resend es `\bre_` en gitleaks y
#    `(^|[^A-Za-z0-9_])re_` aqui. Copiar una en la otra apagaria esta guardia en
#    silencio. Verificado el 26-sep-2026 plantando `re_`, `pre_` y `xre_`.
CONTRATO=contracts/llaves-conocidas.txt
[ -f "$CONTRATO" ] || { echo "::error::falta $CONTRATO: la guardia no tiene de donde leer los patrones."; exit 1; }
LLAVES=$(awk -F'\t' '!/^#/ && NF>=3 {print $3}' "$CONTRATO" | sort -u | paste -sd'|' -)
# Una guardia sin patrones no falla: PASA. Por eso se exige que la lista exista.
[ -n "$LLAVES" ] || { echo "::error::$CONTRATO no dio ningun patron: la guardia quedaria ciega."; exit 1; }
hallazgos=$(git grep -noE "$LLAVES" -- "$yo")
if [ -n "$hallazgos" ]; then
  printf '%s\n' "$hallazgos" | sed -E 's/^([^:]+):([0-9]+):[^A-Za-z0-9]*(.{8}).*$/  \1:\2  \3…/'
  echo '::error::Valor de llave secreta versionado. Ya está en el historial de git: rótala, borrar la línea no basta.'
  fallos=1
fi

# 2. Nada secreto puede viajar con el prefijo que Next publica.
if git grep -InE 'NEXT_PUBLIC_[A-Z_]*(SECRET|SERVICE_ROLE|PRIVATE|_API_KEY)' -- "$yo"; then
  echo '::error::Variable NEXT_PUBLIC_ con nombre de secreto: Next la publica en el bundle.'
  fallos=1
fi

# 3. Un componente de cliente se envía entero al navegador: solo puede leer
#    variables NEXT_PUBLIC_. Todo lo demás pertenece a un módulo de servidor.
# Se busca `use client` sin las comillas: 'use client' y "use client" son
# ambos válidos y un patrón con comillas deja de cubrir el otro estilo en
# silencio. Buscar de más aquí solo amplía la revisión, nunca la reduce.
clientes=$(git grep -l 'use client' -- 'src/' || true)
if [ -n "$clientes" ]; then
  malos=$(printf '%s\n' "$clientes" | while read -r f; do
    grep -nE 'process\.env\.' "$f" | grep -vE 'process\.env\.NEXT_PUBLIC_' | sed "s|^|$f:|"
  done)
  if [ -n "$malos" ]; then
    printf '%s\n' "$malos"
    echo '::error::Componente de cliente leyendo una variable que no es NEXT_PUBLIC_.'
    fallos=1
  fi
fi

[ "$fallos" -eq 0 ] && echo 'Guardia de secretos: sin hallazgos.'
exit "$fallos"
