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
#
# El `- ` del primer renglon de un paso es parte del patron desde el
# 1-oct-2026: sin el, un `- if:` o un `- run:` escrito en el mismo renglon que
# el guion no se revisaba. Ninguno de los diez repos lo escribe asi, asi que la
# ceguera no se veia; la encontro el arnes de este validador.
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
    match($0, /^[ \t]*(-[ \t]+)?if:[ \t]*/) {
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
    match($0, /^[ \t]*(-[ \t]+)?run:[ \t]*/) {
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

# ---------------------------------------------------------------------------
# 4. Que GitHub lea el archivo, y que el archivo sea el que GitHub lee.
#
# POR QUE
# Un workflow que no termina en .yml o .yaml NO lo lee GitHub: no falla, no
# avisa, simplemente no existe. Lo mismo con Dependabot, que solo lee
# exactamente `.github/dependabot.yml`: un `dependabot.yaml` deja el repo sin
# actualizaciones de dependencias y con la configuracion versionada, que es
# peor que no tenerla, porque parece que si esta.
for f in "$dir"/*; do
  [ -f "$f" ] || continue
  case "$f" in
    *.yml|*.yaml) ;;
    *) echo "::error::$f: GitHub solo lee .yml y .yaml en $dir. Este archivo no corre."; fallos=1 ;;
  esac
done

for f in .github/dependabot.*; do
  [ -e "$f" ] || continue
  [ "$f" = ".github/dependabot.yml" ] && continue
  echo "::error::$f: Dependabot solo lee .github/dependabot.yml. Con este nombre la configuracion no aplica."
  fallos=1
done

# ---------------------------------------------------------------------------
# 5. Reglas estructurales: SHA, timeout, continue-on-error y agentes en CI.
#
# POR QUE AWK Y NO UN PARSER
# Este repo se clona y se sirve sin `npm install`: no hay parser de YAML
# disponible, y traer uno rompe una propiedad del repo. Para estas reglas
# alcanza: `uses:`, `timeout-minutes:` y `continue-on-error:` viven siempre en
# posicion de clave, y lo unico que hay que respetar es no mirar dentro de un
# escalar en bloque (donde `uses:` puede ser texto de un `run:`) ni dentro de un
# comentario. Las dos cosas las lleva el mismo seguimiento de sangria.
#
# QUE ATRAPA CADA UNA
# - SHA de 40: la regla de pins es del Nivel 1 del estandar y nada la verificaba.
#   `validar-cadena.sh` cubre el lockfile de npm, no las actions. Una etiqueta
#   movil (`@v4`) la puede reapuntar quien controla el repositorio de la action.
# - `timeout-minutes`: §5.2. Se exige a los jobs con `steps:`; un job que llama
#   a un workflow reutilizable no puede declararlo, y el llamado lo trae.
# - `continue-on-error`: una puerta que no puede tumbar el job no es una puerta.
#   Hoy ninguno de los diez repos lo usa, asi que el trinquete queda en cero.
# - Agentes en CI (§5.9.1): `Bash` en `claude_args` y
#   `--dangerously-skip-permissions`. El 1-oct-2026 el verificador de deriva de
#   `map` corria con diez entradas `Bash(...)`, entre ellas `cat`, `find` y
#   `gh pr comment`, sobre el contenido de cada PR.
for f in "$dir"/*.yml "$dir"/*.yaml; do
  [ -e "$f" ] || continue
  salida=$(awk -v q="'" '
    function recortar(l) { sub(/^[ \t]+/, "", l); sub(/[ \t]+$/, "", l); return l }
    function valor(l,   v, c) {
      v = l
      sub(/^[ \t]*(-[ \t]+)?[^:]*:[ \t]*/, "", v)
      sub(/[ \t]+#.*$/, "", v)
      v = recortar(v)
      c = substr(v, 1, 1)
      if (c == q || c == "\"") v = substr(v, 2, length(v) - 2)
      return v
    }
    function err(ln, msg) { printf "  linea %d: %s\n", ln, msg; mal = 1 }
    function cerrar_job() {
      if (job != "" && tiene_steps && !tiene_timeout)
        err(job_ln, "el job `" job "` declara `steps:` sin `timeout-minutes:` (estandar 5.2)")
      job = ""; tiene_steps = 0; tiene_timeout = 0; sang_prop = -1
    }
    { s = match($0, /[^ \t]/) ? RSTART - 1 : -1 }
    # Dentro de un escalar en bloque. `claude_args` se acumula porque ahi viven
    # los argumentos del agente; del resto no se mira el contenido.
    en_bloque && (s == -1 || s > sang_bloque) {
      if (clave_bloque == "claude_args" || clave_bloque == "args") {
        argumentos = argumentos " " $0
        if (arg_ln == 0) arg_ln = NR
      }
      next
    }
    en_bloque { en_bloque = 0 }
    s == -1 { next }
    /^[ \t]*#/ { next }
    match($0, /^[ \t]*(-[ \t]+)?[A-Za-z0-9_.-]+:[ \t]*[|>][0-9]*[+-]?[ \t]*$/) {
      sang_bloque = s; en_bloque = 1
      clave_bloque = $0
      sub(/^[ \t]*(-[ \t]+)?/, "", clave_bloque); sub(/:.*$/, "", clave_bloque)
      next
    }
    match($0, /^[ \t]*(-[ \t]+)?(claude_args|args):[ \t]*[^|>]/) {
      argumentos = argumentos " " valor($0)
      if (arg_ln == 0) arg_ln = NR
    }
    match($0, /^[ \t]*(-[ \t]+)?uses:[ \t]*/) {
      u = valor($0)
      # Las locales (`uses: ./...`) no tienen SHA que fijar. Para el resto se
      # mide el largo en vez de usar un intervalo {40} en la expresion: no todo
      # awk los soporta, y uno que no los entienda dejaria pasar TODO en
      # silencio, que es el peor modo de falla para una puerta.
      if (u !~ /^\.\//) {
        ref = u
        if (index(ref, "@") == 0) ref = ""
        else sub(/^[^@]*@/, "", ref)
        if (length(ref) != 40 || ref !~ /^[0-9a-f]+$/)
          err(NR, "`uses: " u "` no va fijada por un SHA de 40 caracteres hexadecimales")
      }
    }
    match($0, /^[ \t]*(-[ \t]+)?continue-on-error:[ \t]*/) {
      if (valor($0) == "true")
        err(NR, "`continue-on-error: true`: una puerta que no puede tumbar el job no es una puerta")
    }
    /^[ \t]*(pull_request_target|workflow_run)[ \t]*:/ { disparador = NR }
    /^on:[ \t]*\[/ && /(pull_request_target|workflow_run)/ { disparador = NR }
    /ref:[ \t]*.*(pull_request\.head|workflow_run\.head_sha|head\.sha)/ { checkout_del_pr = NR }
    /^jobs:[ \t]*$/ { en_jobs = 1; sang_jobs = -1; next }
    en_jobs && s == 0 { cerrar_job(); en_jobs = 0 }
    en_jobs {
      if (match($0, /^[ \t]*[A-Za-z0-9_.-]+:[ \t]*(#.*)?$/)) {
        if (sang_jobs == -1) sang_jobs = s
        if (s == sang_jobs) {
          cerrar_job()
          job = $0; sub(/^[ \t]*/, "", job); sub(/:.*$/, "", job); job_ln = NR
          next
        }
      }
      if (job != "") {
        if (sang_prop == -1) sang_prop = s
        if (s == sang_prop) {
          if ($0 ~ /^[ \t]*steps:/) tiene_steps = 1
          if ($0 ~ /^[ \t]*timeout-minutes:/) tiene_timeout = 1
        }
      }
    }
    END {
      cerrar_job()
      if (argumentos ~ /Bash/)
        err(arg_ln, "`Bash` en los argumentos del agente: un agente en CI no tiene shell (§5.9.1 regla 1)")
      if (argumentos ~ /--dangerously-skip-permissions/)
        err(arg_ln, "`--dangerously-skip-permissions` apaga el control de herramientas del agente")
      if (disparador && checkout_del_pr)
        err(disparador, "`pull_request_target`/`workflow_run` con checkout del codigo del PR: corre codigo ajeno con los secretos de la base (§5.9.1 regla 4)")
      else if (disparador)
        printf "  linea %d: AVISO: `pull_request_target`/`workflow_run`. Corre con los secretos de la base; revisa a mano que no haga checkout del codigo del PR.\n", disparador
      exit (mal ? 1 : 0)
    }
  ' "$f") || { echo "::error::$f: incumple una regla estructural del estandar."; printf "%s\n" "$salida"; fallos=1; }
  # El AVISO sale por stdout con exit 0, asi que se imprime aparte.
  [ -n "${salida:-}" ] && printf "%s\n" "$salida" | grep -q 'AVISO' && printf "%s\n" "$salida" | grep 'AVISO' | sed "s|^|$f|"
done

[ "$fallos" -eq 0 ] && echo "Validador de workflows: $n bloque(s) \`run:\` validos, "'`if:`'" con delimitadores cerrados, actions fijadas por SHA, jobs con timeout"
exit "$fallos"
