#!/usr/bin/env bash
# Arnes de `validar-checks-requeridos.sh` (§5.7, «romperla a proposito»).
#
# POR QUE EXISTE
# Este validador es lo UNICO que separa «la proteccion de rama exige los checks
# correctos» de «alguien renombro un job y nadie se enterara hasta que entre algo
# roto a main». Y su modo de falla es silencioso: un comparador de conjuntos que
# compara mal no truena, pasa.
#
# El chequeo 2 --contra la proteccion de rama de verdad-- no se puede probar aqui
# sin tocar la configuracion del repo, asi que se prueba el chequeo 1, que es el
# que atrapa el caso que BLOQUEA PRs: un check requerido que ningun workflow
# produce.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ=$PWD

fixture=$(mktemp -d); trap 'rm -rf "$fixture"' EXIT
casos=0; fallos=0

# Un repo de juguete. Sintetico a proposito: atado al contrato vivo, el arnes se
# rompe el dia que el contrato cambie por una razon legitima.
armar() {
  rm -rf "$fixture"; mkdir -p "$fixture/scripts" "$fixture/contracts" "$fixture/.github/workflows"
  cp "$RAIZ/scripts/validar-checks-requeridos.sh" "$fixture/scripts/"
  cat > "$fixture/contracts/checks-requeridos.txt" <<'FIN'
# Contrato sintetico del arnes. No es el del repo.
Gatekeeper
Calidad de mentira
analyze
FIN
  cat > "$fixture/.github/workflows/a.yml" <<'FIN'
name: Puerta
on:
  pull_request:
jobs:
  gatekeeper:
    name: Gatekeeper
    runs-on: ubuntu-latest
    steps: [{ run: 'true' }]
  calidad:
    name: Calidad de mentira
    runs-on: ubuntu-latest
    steps: [{ run: 'true' }]
FIN
  cat > "$fixture/.github/workflows/b.yml" <<'FIN'
name: CodeQL
on:
  pull_request:
jobs:
  analyze:
    runs-on: ubuntu-latest
    steps: [{ run: 'true' }]
FIN
}

# El chequeo 2 necesita red y un repo real; aqui se neutraliza con un `gh` falso
# que no devuelve nada, que es la rama «no se pudo leer» --la que avisa sin
# fallar--. Asi lo que se mide es solo el chequeo 1.
falso=$(mktemp -d)
# OJO: este doble falla CALLADO, y asi tenia un punto ciego. El `gh` de verdad
# ante un 403 sale con codigo != 0 **y escribe el cuerpo del error en stdout**,
# que es lo que rompio el validador en CI el 12-oct-2026. El caso de abajo
# --«gh falla imprimiendo un cuerpo de error»-- cubre eso.
printf '#!/bin/sh\nexit 1\n' > "$falso/gh"; chmod +x "$falso/gh"
gh_que_escupe_error() {
  printf '#!/bin/sh\nprintf \x27{"message":"Resource not accessible by integration","status":"403"}\n\x27\nexit 1\n' > "$falso/gh"
  chmod +x "$falso/gh"
}
gh_callado() { printf '#!/bin/sh\nexit 1\n' > "$falso/gh"; chmod +x "$falso/gh"; }
correr() { ( cd "$fixture" && PATH="$falso:$PATH" ./scripts/validar-checks-requeridos.sh 2>&1 ); }

# exige <titulo> <texto esperado en el error>
exige() {
  local titulo="$1" texto="$2" salida codigo
  casos=$((casos + 1))
  salida=$(correr); codigo=$?
  if [ "$codigo" -eq 0 ]; then
    echo "::error::$titulo: el validador PASO. Esta ciego a este caso."
    fallos=1; return
  fi
  if ! printf '%s' "$salida" | grep -qF -- "$texto"; then
    echo "::error::$titulo: fallo, pero no por «$texto»:"
    printf '%s\n' "$salida" | sed 's/^/    /'
    fallos=1
  else
    printf '  ok   %s\n' "$titulo"
  fi
}

echo 'Arnes del contrato de checks requeridos:'

# EL CASO QUE MOTIVA TODO: un job renombrado deja un check requerido huerfano, y
# un check requerido que no aparece bloquea el PR para siempre.
armar
sed -i.bak 's/name: Calidad de mentira/name: Calidad con otro nombre/' "$fixture/.github/workflows/a.yml"
exige 'un job renombrado' 'NINGUN workflow de pull_request produce'

# Un workflow que deja de dispararse en pull_request produce el mismo agujero,
# por otro camino: el job sigue ahi pero su check ya no aparece en los PR.
armar
sed -i.bak 's/^on:$/on:\n  push: { branches: [main] }/; s/^  pull_request:$//' "$fixture/.github/workflows/b.yml"
exige 'un workflow que ya no corre en PR' 'NINGUN workflow de pull_request produce'

# Un job sin `name:` reporta con su id. Si el validador no lo supiera, `analyze`
# daria falso negativo y el contrato se volveria imposible de cumplir.
armar
sed -i.bak 's/^  analyze:$/  otro_id:/' "$fixture/.github/workflows/b.yml"
exige 'un job sin name: cuyo id cambia' 'NINGUN workflow de pull_request produce'

# Y el contrato vacio o ausente no puede pasar por «todo en orden».
armar
printf '# solo comentarios\n' > "$fixture/contracts/checks-requeridos.txt"
exige 'un contrato sin ningun check' 'no declara ningun check'

armar
rm "$fixture/contracts/checks-requeridos.txt"
exige 'el contrato ausente' 'falta contracts/checks-requeridos.txt'

# --- y que en verde si pase -------------------------------------------------
armar
casos=$((casos + 1))
salida=$(correr); codigo=$?
if [ "$codigo" -ne 0 ]; then
  echo '::error::el fixture intacto no pasa: el arnes o el validador estan mal'
  printf '%s\n' "$salida" | sed 's/^/    /'
  fallos=1
else
  echo '  ok   el fixture intacto pasa'
  # Y avisa que no pudo leer la proteccion, en vez de callarlo.
  if ! printf '%s' "$salida" | grep -qF 'no se pudo leer la proteccion'; then
    echo '::error::con la proteccion ilegible deberia AVISARLO, y no lo dijo.'
    fallos=1
  else
    echo '  ok   con la proteccion ilegible avisa, no pasa en silencio'
    casos=$((casos + 1))
  fi
fi

# EL DEFECTO QUE SE ESCAPO A CI: `gh` falla y escribe el cuerpo del error en
# stdout. Una guarda de «salida vacia» lo toma por una lista de checks y reporta
# una divergencia inventada. Tiene que caer en la rama de «no se pudo leer».
armar
gh_que_escupe_error
casos=$((casos + 1))
salida=$(correr); codigo=$?
if [ "$codigo" -ne 0 ]; then
  echo '::error::con un gh que falla escupiendo un error, el validador FALLA en vez de avisar.'
  printf '%s\n' "$salida" | sed 's/^/    /'
  fallos=1
elif ! printf '%s' "$salida" | grep -qF 'no se pudo leer la proteccion'; then
  echo '::error::con un gh que falla escupiendo un error, deberia AVISARLO.'
  printf '%s\n' "$salida" | sed 's/^/    /'
  fallos=1
else
  echo '  ok   un gh que falla escupiendo un cuerpo de error no se toma por datos'
fi
gh_callado

rm -rf "$falso"
echo
if [ "$fallos" -eq 0 ]; then
  echo "Arnes del contrato de checks: $casos casos, todos como se esperaba."
else
  echo '::error::el validador de checks requeridos esta ciego a algo que deberia ver.'
fi
exit "$fallos"
