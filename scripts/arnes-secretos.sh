#!/usr/bin/env bash
# Arnes de llaves plantadas: comprueba que LOS DOS motores atrapen lo mismo
# (estandar Meridian 5.7, renglon 1b).
#
# POR QUE
# Los secretos se buscan con dos motores distintos y cada uno tiene su propia
# ceguera, medida el 26-sep-2026:
#   · `git grep -E` (arbol)  no soporta `\b`: el patron compila y casa CERO veces.
#   · gitleaks 8.30.1 (historial) se salta una rama de una alternacion: con
#     `shp(tka|at|ss|ca|sa)_` no ve shpss_.
# Las cegueras NO se solapan, asi que un patron correcto para uno puede ser inerte
# para el otro, y ninguna de las dos formas de fallar avisa: un chequeo que no ve
# nada informa que todo cuadra.
#
# COMO
# Planta una llave de formato valido por cada tipo que el portafolio dice cubrir,
# en un repo temporal, y exige que AMBOS motores la atrapen. Mas trampas que NO
# deben casar. Si una lista se queda atras, aqui se ve.
#
# No modifica el repo: todo pasa en un directorio temporal que se borra al salir.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1
RAIZ=$PWD

# Los patrones salen del CONTRATO, no de la guardia. Este arnes leia antes todas
# las variables `LLAVES*` de `guardia-secretos.sh` —stellium tenia los prefijos de
# Shopify en su propio `LLAVES_SHOPIFY`—, y ese acoplamiento era justo la
# enfermedad: cada repo escribia su lista a mano y el arnes comprobaba la lista
# local contra si misma, asi que una copia podia quedarse corta sin que nada lo
# dijera. A `map` le faltaron `shpca_` y `shpsa_` cinco semanas. Ahora los tres
# lugares leen la misma tabla y el arnes comprueba el CONJUNTO del portafolio.
# Absoluta: mas abajo este script hace `cd "$TMP"`, y una ruta relativa se rompe ahi.
CONTRATO="$RAIZ/contracts/llaves-conocidas.txt"
[ -f "$CONTRATO" ] || { echo "::error::falta $CONTRATO."; exit 1; }
LLAVES=$(awk -F'\t' '!/^#/ && NF>=3 {print $3}' "$CONTRATO" | sort -u | paste -sd'|' -)
[ -n "$LLAVES" ] || { echo "::error::$CONTRATO no dio ningun patron."; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1   # sin esta guarda, un cd fallido deja el `git init` en el REPO
git init -q .

# El relleno tiene que PARECER una llave: aleatorio, no un alfabeto en orden.
# gitleaks filtra por entropia, asi que un relleno secuencial de 30 caracteres da
# CERO hallazgos y el arnes reportaria que los dos motores estan ciegos cuando el
# ciego es el fixture. Medido el 30-sep-2026: aleatorio acierta en toda longitud,
# secuencial falla a partir de ~30. Un arnes con fixtures falsos miente igual que
# el chequeo que pretende vigilar.
R=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 30)
plantar() { printf 'k = "%s"\n' "$2" > "$1.txt"; }

# Un archivo por FILA del contrato. Antes esta lista estaba escrita a mano aqui,
# y nada comprobaba que cubriera lo que el portafolio dice reconocer: quitarle un
# tipo hacia que el arnes pasara en verde con uno menos y lo dijera en el mensaje,
# pero nada fallaba. Ahora no se puede: lo que se planta ES el contrato.
TIPOS=$(awk -F'\t' '!/^#/ && NF>=3 {print $1}' "$CONTRATO" | paste -sd' ' -)
[ -n "$TIPOS" ] || { echo "::error::$CONTRATO no dio ningun tipo."; exit 1; }
# El relleno respeta la clase que el patron exige. Sin esto, `AKIA` mas un relleno
# con minusculas no casa con `AKIA[0-9A-Z]{16}`, y el arnes reportaba los DOS
# motores ciegos cuando el ciego era el fixture.
relleno() {   # relleno <alfabeto:largo o vacio>
  local spec="${1:-A-Za-z0-9:30}" abc largo
  abc=${spec%:*}; largo=${spec##*:}
  LC_ALL=C tr -dc "$abc" </dev/urandom | head -c "$largo"
}
while IFS=$'\t' read -r tipo prefijo _ spec; do
  case "$tipo" in ''|'#'*) continue ;; esac
  # Las llaves se arman al vuelo y nunca literales: un prefijo seguido del relleno
  # ES una llave con formato valido, y escribirla aqui la haria aparecer en el
  # arbol de este repo, donde la propia guardia la marcaria —lo hizo—.
  plantar "$tipo" "${prefijo}$(relleno "$spec")"
done < <(grep -v '^#' "$CONTRATO" | awk -F'\t' 'NF>=3')

# Trampas: no deben casar ninguna.
plantar t_pre    "pre_$R"          # `re_` sin frontera de palabra
plantar t_shpzz  "shpzz_$R"        # prefijo de Shopify inexistente
plantar t_corta  "sb_secret_abc"   # por debajo del piso de longitud
TRAMPAS="t_pre t_shpzz t_corta"

git add -A >/dev/null 2>&1

arbol=$(git grep -lE "$LLAVES" 2>/dev/null | sed 's/\.txt$//' | sort -u)

gl=""; GL_CORRIO=0
GL="$("$RAIZ/scripts/traer-gitleaks.sh" 2>/dev/null || true)"
if [ -n "$GL" ]; then
  if "$GL" detect --no-git --source . --config "$RAIZ/.gitleaks.toml" \
       --report-format json --report-path r.json --redact >/dev/null 2>&1 || [ -f r.json ]; then
    gl=$(python3 -c "
import json,os,sys
try: d=json.load(open('r.json'))
except Exception: sys.exit(0)
for x in d: print(os.path.basename(x.get('File','')).removesuffix('.txt'))
" 2>/dev/null | sort -u)
    GL_CORRIO=1
  fi
fi

fallos=0
printf '  %-12s %-10s %s\n' TIPO arbol historial
for t in $TIPOS; do
  if grep -qx "$t" <<<"$arbol"; then a=si; else a=NO; fi
  if [ "$GL_CORRIO" = 1 ]; then
    if grep -qx "$t" <<<"$gl"; then g=si; else g=NO; fi
  else g="(sin correr)"; fi
  printf '  %-12s %-10s %s\n' "$t" "$a" "$g"
  [ "$a" = NO ] && fallos=1
  [ "$g" = NO ] && fallos=1
done
for t in $TRAMPAS; do
  if grep -qx "$t" <<<"$arbol"; then a=CASA; else a=no; fi
  [ "$a" = CASA ] && { echo "::error::La trampa $t casa en el arbol: falso positivo."; fallos=1; }
done

if [ "$GL_CORRIO" = 0 ]; then
  echo '::warning::gitleaks no esta instalado: la mitad del historial NO se comprobo. El arnes solo valida el arbol.'
fi
if [ "$fallos" -ne 0 ]; then
  echo '::error::Los dos motores no atrapan lo mismo. Una de las dos listas se quedo atras.'
  exit 1
fi
echo "Arnes de secretos: los dos motores atrapan los $(wc -w <<<"$TIPOS" | tr -d ' ') tipos, y ninguna trampa."
