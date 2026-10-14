#!/usr/bin/env bash
# Valida el contrato de checks requeridos (§12 del estandar), en DOS sentidos:
#
#   1. Lo que `contracts/checks-requeridos.txt` declara existe como job en algun
#      workflow que se dispare en `pull_request`. Un nombre que no exista es un
#      check requerido que NUNCA aparece, y eso bloquea el PR para siempre.
#   2. Lo que la proteccion de rama exige DE VERDAD coincide con el contrato.
#      Un check que se renombra deja de exigirse en silencio; esto lo grita.
#
# POR QUE EXISTE
# Hasta el 12-oct-2026 la proteccion exigia un solo nombre y `upsidr/merge-gatekeeper`
# agregaba los demas esperandolos en un runner. Costaba ~1,800 min al mes en
# minutos de Actions por un job que no hacia nada. Enumerar es mas barato y mas
# fragil; esto cambia la fragilidad por una puerta.
#
# EL CHEQUEO 2 NO PUEDE CORRER EN CI, Y NO ES POR FALTA DE CONFIGURARLO
# Leer la proteccion de rama exige derechos de admin, y `GITHUB_TOKEN` no los
# tiene: `administration` **no existe** como scope de ese token --lo confirma
# actionlint-- asi que no hay bloque `permissions:` que lo arregle. Haria falta
# un PAT, y meter un secreto en CI cuesta mas de lo que compra.
#
# Donde si corre es en la Puerta 1, con el `gh` de quien commitea. Y eso no es
# «a mano»: la Puerta 1 corre en cada commit, que es justo lo que le faltaba al
# arnes de deriva cuando quedo inservible cinco dias sin que nadie lo notara.
#
# Si no se puede leer, el chequeo 2 avisa y NO falla. El 1 es el que atrapa el
# modo de falla que bloquea PRs, y ese si corre en CI.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONTRATO=contracts/checks-requeridos.txt
# El repo sale del remoto y no escrito a mano: estos scripts viven en siete
# repos, y una copia con el nombre de otro compararia contra la proteccion
# equivocada y pasaria en verde. `GH_REPO` lo fuerza en CI.
REPO="${GH_REPO:-$(git remote get-url origin 2>/dev/null \
        | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
# Si no se puede deducir, NO se muere: es el mismo caso que «no pude leer la
# proteccion», y el chequeo 1 --el que atrapa lo que bloquea PRs-- si puede
# correr. Morir aqui dejaba sin medir la mitad que si sirve.
fallos=0

[ -f "$CONTRATO" ] || { echo "::error::falta $CONTRATO"; exit 1; }

# El contrato: una linea por check, sin comentarios ni vacias.
declarados=$(grep -vE '^[[:space:]]*(#|$)' "$CONTRATO")
[ -n "$declarados" ] || { echo "::error::$CONTRATO no declara ningun check"; exit 1; }
n_decl=$(printf '%s\n' "$declarados" | wc -l | tr -d ' ')

# --- 1) cada declarado existe como job en un workflow de pull_request --------
#
# El nombre del check es el `name:` del job si lo tiene, y su id si no. Se saca
# con node, que ya es dependencia del repo, sin un parser de YAML: se lee la
# indentacion, que en estos workflows es constante.
presentes=$(node -e '
  const fs = require("fs"), path = ".github/workflows";
  const out = new Set();
  for (const f of fs.readdirSync(path).filter(x => /\.ya?ml$/.test(x))) {
    const texto = fs.readFileSync(path + "/" + f, "utf8");
    // Solo workflows que se disparan en pull_request: los demas no producen
    // checks que la proteccion pueda exigir.
    if (!/^\s{0,2}pull_request:/m.test(texto)) continue;
    const lineas = texto.split("\n");
    let enJobs = false, idActual = null, nombre = null;
    const cerrar = () => { if (idActual) out.add(nombre || idActual); idActual = null; nombre = null; };
    for (const l of lineas) {
      if (/^jobs:\s*$/.test(l)) { enJobs = true; continue; }
      if (!enJobs) continue;
      if (/^\S/.test(l)) { cerrar(); enJobs = false; continue; }
      const job = l.match(/^  ([A-Za-z0-9_-]+):\s*$/);
      if (job) { cerrar(); idActual = job[1]; continue; }
      const nom = l.match(/^    name:\s*(.+?)\s*$/);
      if (nom && idActual && nombre === null) nombre = nom[1].replace(/^["\x27]|["\x27]$/g, "");
    }
    cerrar();
  }
  console.log([...out].join("\n"));
')

faltan=''
while IFS= read -r c; do
  printf '%s\n' "$presentes" | grep -qxF -- "$c" || faltan="$faltan$c"$'\n'
done <<< "$declarados"

if [ -n "$faltan" ]; then
  echo '::error::checks declarados que NINGUN workflow de pull_request produce:'
  printf '%s' "$faltan" | sed 's/^/    /'
  echo '  Un check requerido que no aparece bloquea el PR para siempre (§12).'
  echo '  O el job se renombro, o el workflow dejo de dispararse en pull_request.'
  fallos=1
else
  echo "Contrato de checks: los $n_decl declarados existen como job."
fi

# --- 2) y la proteccion de rama exige exactamente eso ------------------------
# OJO CON COMO SE DETECTA QUE NO SE PUDO LEER
# No basta con «la salida esta vacia». `gh api` ante un 403 sale con codigo != 0
# **y escribe el cuerpo del error en stdout**, asi que una guarda de vacio lo
# toma por una lista de checks y reporta una divergencia inventada. Paso en CI el
# 12-oct-2026: el contrato salio rojo diciendo que la proteccion no exigia nada,
# con un `{"message":"Resource not accessible by integration"}` de contenido.
# Se mira el codigo de salida, y de pilon se descarta cualquier cosa con forma de
# JSON por si algun dia sale con 0.
if exigidos=$(gh api "/repos/$REPO/branches/main/protection" \
                --jq '.required_status_checks.contexts[]?' 2>/dev/null); then
  case "$exigidos" in *'{'*|*'"message"'*) exigidos='' ;; esac
else
  exigidos=''
fi
if [ -z "$exigidos" ]; then
  echo '::notice::no se pudo leer la proteccion de rama (hace falta `administration: read`).'
  echo '  El chequeo 1 si corrio. Este queda sin comprobar, no en verde.'
else
  de_mas=$(comm -13 <(printf '%s\n' "$declarados" | sort) <(printf '%s\n' "$exigidos" | sort))
  de_menos=$(comm -23 <(printf '%s\n' "$declarados" | sort) <(printf '%s\n' "$exigidos" | sort))
  if [ -n "$de_mas" ] || [ -n "$de_menos" ]; then
    echo '::error::la proteccion de rama y el contrato no coinciden.'
    [ -n "$de_menos" ] && { echo '  declarados que la proteccion NO exige:'; printf '%s' "$de_menos" | sed 's/^/    /'; }
    [ -n "$de_mas" ] && { echo '  exigidos que el contrato no declara:'; printf '%s' "$de_mas" | sed 's/^/    /'; }
    fallos=1
  else
    echo "Proteccion de rama: exige exactamente los $n_decl del contrato."
  fi
fi

exit "$fallos"
