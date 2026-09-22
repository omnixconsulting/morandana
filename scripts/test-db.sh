#!/usr/bin/env bash
# Corre las pruebas SQL (supabase/tests/*.sql) contra la base local. Cada
# archivo usa bloques DO que lanzan excepción si una aserción falla.
#   ./scripts/base-local.sh && ./scripts/test-db.sh
set -euo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
URL="${MORANDANA_DB_URL:-postgresql://postgres@localhost:${PGPUERTO:-55434}/${DB:-morandana}}"
fallas=0
for f in "$RAIZ"/supabase/tests/*.sql; do
  if out=$(psql "$URL" -q -v ON_ERROR_STOP=1 -f "$f" 2>&1); then
    printf '   ok    %s\n' "$(basename "$f")"
  else
    printf '   FALLA %s\n%s\n' "$(basename "$f")" "$out"; fallas=$((fallas+1))
  fi
done
[ "$fallas" = 0 ] && echo "Pruebas SQL: todas pasan" || { echo "Pruebas SQL: $fallas archivo(s) con fallas"; exit 1; }
