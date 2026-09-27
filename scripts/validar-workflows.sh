#!/usr/bin/env bash
# Valida que GitHub pueda LEER cada `if:` de los workflows (estandar Meridian, L0).
#
# POR QUE
# Un `if:` roto no da error: YAML lo corta y el workflow queda invalido o la
# condicion cambia de sentido, sin que nada avise. El 23-sep-2026 un
# `if: ... 'Merge pull request #')` sin comillas dobles hizo que YAML tomara el
# ` #` como inicio de comentario y truncara la expresion. El archivo PARSEA: el
# valor queda `...'Merge pull request` con un parentesis y una comilla sin cerrar.
# Por eso no basta con un parser de YAML; hay que mirar el valor YA cortado.
#
# Emula la regla exacta que lo causa: en un escalar plano, un espacio seguido de
# almohadilla abre comentario. En un escalar entrecomillado o en un bloque
# (`>`/`|`) la almohadilla es literal, y ahi no se corta.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

dir=.github/workflows
[ -d "$dir" ] || { echo 'Validador de workflows: no hay .github/workflows.'; exit 0; }

fallos=0
for f in "$dir"/*.yml "$dir"/*.yaml; do
  [ -e "$f" ] || continue
  salida=$(awk '
    function limpiar(v) {           # corta el comentario de un escalar plano
      if (v ~ /^['"'"'"]/) return v # entrecomillado: la almohadilla es literal
      sub(/[ \t]+#.*$/, "", v)
      return v
    }
    function revisar(v, ln,   i, c, par, cor, lla, si, di) {
      par=0; cor=0; lla=0; si=0; di=0
      for (i=1; i<=length(v); i++) {
        c = substr(v,i,1)
        if (c=="(") par++; else if (c==")") par--
        else if (c=="[") cor++; else if (c=="]") cor--
        else if (c=="{") lla++; else if (c=="}") lla--
        else if (c=="'"'"'") si++; else if (c=="\"") di++
      }
      m=""
      if (par!=0) m=m " parentesis(" par ")"
      if (cor!=0) m=m " corchetes(" cor ")"
      if (lla!=0) m=m " llaves(" lla ")"
      if (si%2)   m=m " comilla-simple-impar"
      if (di%2)   m=m " comilla-doble-impar"
      if (m!="") printf "  linea %d:%s\n    valor: %s\n", ln, m, v
      return (m!="")
    }
    # dentro de un bloque >/| : acumular mientras la sangria sea mayor
    bloque && match($0, /^[ \t]*/) && RLENGTH > sangria && $0 ~ /[^ \t]/ {
      gsub(/^[ \t]+|[ \t]+$/, ""); acum = acum " " $0; next
    }
    bloque { if (revisar(acum, ln)) mal=1; bloque=0 }
    match($0, /^[ \t]*if:[ \t]*/) {
      sangria = index($0, "if:") - 1
      v = substr($0, RSTART+RLENGTH)
      ln = NR
      if (v ~ /^[>|]/) { bloque=1; acum=""; next }
      if (revisar(limpiar(v), ln)) mal=1
    }
    END { if (bloque && revisar(acum, ln)) mal=1; exit (mal?1:0) }
  ' "$f") || { echo "::error::$f: expresion \`if:\` con delimitadores sin cerrar."; echo "$salida"; fallos=1; }
done

[ "$fallos" -eq 0 ] && echo 'Validador de workflows: todos los `if:` cierran sus delimitadores.'
exit "$fallos"
