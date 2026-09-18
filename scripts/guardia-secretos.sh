#!/usr/bin/env bash
# Guardia de secretos (estándar Meridian, capa L0).
#
# En Next, todo lo que empieza con NEXT_PUBLIC_ se inyecta en el bundle del
# navegador, y un componente con "use client" se envía completo al cliente.
# Revisa únicamente archivos versionados —lo que no está en git no se despliega.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fallos=0
yo=':!scripts/guardia-secretos.sh'

# 1. Valores de llaves secretas en cualquier archivo versionado. Los patrones
#    exigen longitud de llave real para no marcar menciones en comentarios.
if git grep -InE 'sb_secret_[A-Za-z0-9_-]{20,}|sk-ant-[A-Za-z0-9_-]{24,}|re_[A-Za-z0-9_-]{24,}|AKIA[0-9A-Z]{16}' -- "$yo"; then
  echo '::error::Valor de llave secreta versionado.'
  fallos=1
fi

# 2. Nada secreto puede viajar con el prefijo que Next publica.
if git grep -InE 'NEXT_PUBLIC_[A-Z_]*(SECRET|SERVICE_ROLE|PRIVATE|_API_KEY)' -- "$yo"; then
  echo '::error::Variable NEXT_PUBLIC_ con nombre de secreto: Next la publica en el bundle.'
  fallos=1
fi

# 3. Un componente de cliente se envía entero al navegador: solo puede leer
#    variables NEXT_PUBLIC_. Todo lo demás pertenece a un módulo de servidor.
clientes=$(git grep -l '"use client"' -- 'src/' || true)
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
