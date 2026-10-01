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


# ---------------------------------------------------------------------------
# 2. Cada `run:` tiene que ser shell valido.
#
# POR QUE NO BASTA CON QUE EL YAML PARSEE
# El 30-sep un paso insertado mal dejo un `fi` huerfano: el YAML parseaba, los
# pasos se listaban en orden, y CI murio con «line 5: syntax error». Un `run:`
# roto es un escalar multilinea perfectamente valido para YAML. Y actionlint
# tampoco lo atrapa: delega el shell a shellcheck y, si shellcheck no esta
# instalado, se lo SALTA EN SILENCIO —medido el 1-oct-2026—.
cuerpos=$(mktemp -d); trap 'rm -rf "$cuerpos"' EXIT
n=0
for f in "$dir"/*.yml "$dir"/*.yaml; do
  [ -e "$f" ] || continue
  # Extrae cada bloque `run:` con su sangria, igual que arriba con `if:`.
  awk -v dest="$cuerpos" -v arch="$(basename "$f")" '
    function volcar() {
      if (acum != "") { printf "%s", acum > (dest "/" arch "." ln ".sh"); close(dest "/" arch "." ln ".sh") }
      acum = ""
    }
    bloque && match($0, /^[ \t]*/) && RLENGTH > sangria && $0 ~ /[^ \t]/ {
      linea = substr($0, sangria + 3); acum = acum linea "\n"; next
    }
    bloque { volcar(); bloque = 0 }
    match($0, /^[ \t]*run:[ \t]*/) {
      sangria = index($0, "run:") - 1
      v = substr($0, RSTART + RLENGTH); ln = NR
      if (v ~ /^[>|]/) { bloque = 1; acum = "" }
      else if (v != "") { acum = v "\n"; volcar() }
    }
    END { if (bloque) volcar() }
  ' "$f"
done
for c in "$cuerpos"/*.sh; do
  [ -e "$c" ] || continue
  n=$((n + 1))
  if ! salida=$(bash -n "$c" 2>&1); then
    arch=$(basename "$c"); arch=${arch%.sh}
    echo "::error::$dir/${arch%.*}: el \`run:\` de la linea ${arch##*.} no es shell valido."
    printf '%s\n' "$salida" | sed "s|$c|run|" | sed 's/^/    /'
    fallos=1
  fi
done

# ---------------------------------------------------------------------------
# 3. actionlint: la red mas ancha. Atrapa expresiones mal formadas que los dos
#    chequeos de arriba no ven —el `if:` truncado del 23-sep, por ejemplo—.
#    Si no se puede traer, se dice: media comprobacion en verde es el vicio.
# El stderr del buscador NO se tira: ahi viaja el error de checksum, que es el mas
# importante que puede emitir. Tirarlo convertiria «el binario no coincide con su
# hash» en «no se pudo traer actionlint», y un compromiso de cadena de suministro
# se veria igual que una falla de red.
err=$(mktemp); trap 'rm -rf "$cuerpos" "$err"' EXIT
if AL=$(./scripts/traer-actionlint.sh 2>"$err") && [ -n "$AL" ]; then
  if ! salida=$("$AL" 2>&1); then
    echo '::error::actionlint encontro problemas en los workflows.'
    printf '%s\n' "$salida" | head -20 | sed 's/^/    /'
    fallos=1
  fi
  command -v shellcheck >/dev/null 2>&1 \
    || echo '::notice::shellcheck no esta instalado: actionlint se salta el analisis del shell. Lo cubre el chequeo 2 con bash -n.'
else
  echo '::warning::No se pudo traer actionlint: la tercera comprobacion NO corrio. Los `if:` y los `run:` si se revisaron.'
  [ -s "$err" ] && sed 's/^/    /' "$err"
  # Un checksum que no coincide no es una falla de red: es una puerta de calidad
  # a punto de ejecutar un binario que no es el que se fijo. Eso no se avisa, se
  # falla.
  if grep -q 'checksum' "$err" 2>/dev/null; then
    echo '::error::El checksum de actionlint no coincidio. Esto no es un aviso.'
    fallos=1
  fi
fi

[ "$fallos" -eq 0 ] && echo "Validador de workflows: $n bloque(s) \`run:\` validos, "'`if:`'" con delimitadores cerrados"
exit "$fallos"
