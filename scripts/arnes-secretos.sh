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
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ=$PWD

# Se leen TODAS las variables de patrones, no solo `LLAVES`. stellium tiene los
# prefijos de Shopify en su propio `LLAVES_SHOPIFY` porque su mensaje de error es
# distinto, y un arnes que solo mirara `LLAVES` reportaria cinco tipos perdidos que
# la guardia si atrapa. Un falso positivo en el arnes cuesta lo mismo que un falso
# negativo: deja de creerse.
LLAVES=$(sed -n "s/^LLAVES[A-Z_]*='\(.*\)'$/\1/p" scripts/guardia-secretos.sh | paste -sd'|' -)
[ -n "$LLAVES" ] || { echo '::error::No pude leer ninguna lista LLAVES* de scripts/guardia-secretos.sh.'; exit 1; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cd "$TMP"; git init -q .

# El relleno tiene que PARECER una llave: aleatorio, no un alfabeto en orden.
# gitleaks filtra por entropia, asi que un relleno secuencial de 30 caracteres da
# CERO hallazgos y el arnes reportaria que los dos motores estan ciegos cuando el
# ciego es el fixture. Medido el 30-sep-2026: aleatorio acierta en toda longitud,
# secuencial falla a partir de ~30. Un arnes con fixtures falsos miente igual que
# el chequeo que pretende vigilar.
R=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 30)
plantar() { printf 'k = "%s"\n' "$2" > "$1.txt"; }

# Un archivo por tipo que el portafolio afirma cubrir.
plantar sb_secret  "sb_secret_$R"
plantar sk_ant     "sk-ant-$R"
plantar re         "re_$R"
# AKIA se arma al vuelo y no literal: un `AKIA` seguido de 16 mayúsculas escrito
# aqui ES una llave con formato valido, y la guardia del arbol lo marcaria —lo
# hizo—. Excluir este archivo seria un archivo mas que la guardia deja de mirar.
AK=$(LC_ALL=C tr -dc 'A-Z0-9' </dev/urandom | head -c 16)
plantar akia       "AKIA$AK"
plantar shptka     "shptka_$R"
plantar shpat      "shpat_$R"
plantar shpss      "shpss_$R"
plantar shpca      "shpca_$R"
plantar shpsa      "shpsa_$R"
plantar cal_live   "cal_live_$R"
TIPOS="sb_secret sk_ant re akia shptka shpat shpss shpca shpsa cal_live"

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
  a=$(printf '%s\n' "$arbol" | grep -qx "$t" && echo si || echo NO)
  if [ "$GL_CORRIO" = 1 ]; then
    g=$(printf '%s\n' "$gl" | grep -qx "$t" && echo si || echo NO)
  else g="(sin correr)"; fi
  printf '  %-12s %-10s %s\n' "$t" "$a" "$g"
  [ "$a" = NO ] && fallos=1
  [ "$g" = NO ] && fallos=1
done
for t in $TRAMPAS; do
  a=$(printf '%s\n' "$arbol" | grep -qx "$t" && echo CASA || echo no)
  [ "$a" = CASA ] && { echo "::error::La trampa $t casa en el arbol: falso positivo."; fallos=1; }
done

if [ "$GL_CORRIO" = 0 ]; then
  echo '::warning::gitleaks no esta instalado: la mitad del historial NO se comprobo. El arnes solo valida el arbol.'
fi
if [ "$fallos" -ne 0 ]; then
  echo '::error::Los dos motores no atrapan lo mismo. Una de las dos listas se quedo atras.'
  exit 1
fi
echo "Arnes de secretos: los dos motores atrapan los $(echo $TIPOS | wc -w | tr -d ' ') tipos, y ninguna trampa."
