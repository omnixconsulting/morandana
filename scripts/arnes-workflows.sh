#!/usr/bin/env bash
# Arnes del validador de workflows: planta un workflow roto de cada tipo y exige
# que el validador lo atrape (§5.7, «romperla a proposito»).
#
# POR QUE EXISTE
# Las comprobaciones del validador son expresiones regulares sobre YAML, y una
# expresion que deja de casar no falla: pasa. El modo de falla de una puerta de
# regex es el silencio, igual que el de la guardia de secretos, y por eso lleva
# el mismo tratamiento. El comentario del propio validador lo dice para el caso
# del intervalo {40}: un awk que no entienda intervalos dejaria pasar TODO sin
# avisar.
#
# QUE NO HACE
# No valida que el validador sea correcto, solo que no este ciego. Cada caso
# exige el mensaje especifico, no un exit distinto de cero: asi un fallo de
# actionlint por otra razon no se puede confundir con el hallazgo que se busca.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ=$PWD

SHA=0123456789abcdef0123456789abcdef01234567   # 40 hex, no resuelve a nada real
fallos=0
casos=0

fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/scripts" "$fixture/.github/workflows"
cp "$RAIZ/scripts/validar-workflows.sh" "$fixture/scripts/"
cp "$RAIZ/scripts/traer-actionlint.sh" "$fixture/scripts/" 2>/dev/null || true
# actionlint se niega a correr fuera de un repositorio git: sin esto cada caso
# fallaria por esa razon y no por el hallazgo que se busca.
git -C "$fixture" -c init.defaultBranch=main init -q

# plantar <nombre> <marcador esperado, o VERDE>  <<< contenido del workflow
plantar() {
  local nombre=$1 esperado=$2 contenido salida codigo
  contenido=$(cat)
  casos=$((casos + 1))
  rm -f "$fixture"/.github/workflows/* "$fixture"/.github/dependabot.* 2>/dev/null
  # Siempre presente: el caso valido lo invoca para probar que un job que llama
  # a un workflow reutilizable queda exento de `timeout-minutes`, que no lo
  # puede declarar.
  printf 'name: otro\non:\n  workflow_call:\njobs:\n  otro:\n    timeout-minutes: 5\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' > "$fixture/.github/workflows/otro.yaml"
  if [ "$nombre" = "DEPENDABOT" ]; then
    printf '%s\n' "$contenido" > "$fixture/.github/dependabot.yaml"
    printf 'name: v\non:\n  pull_request:\njobs:\n  v:\n    timeout-minutes: 5\n    runs-on: ubuntu-latest\n    steps:\n      - run: true\n' > "$fixture/.github/workflows/valido.yml"
  else
    printf '%s\n' "$contenido" > "$fixture/.github/workflows/$nombre"
  fi
  salida=$(cd "$fixture" && ./scripts/validar-workflows.sh 2>&1); codigo=$?
  if [ "$esperado" = "VERDE" ]; then
    if [ "$codigo" -eq 0 ]; then
      printf '  ok   %-28s en verde, como debe\n' "$nombre"
    else
      printf '  MAL  %-28s deberia pasar y fallo:\n' "$nombre"
      printf '%s\n' "$salida" | sed 's/^/         /'
      fallos=1
    fi
    return
  fi
  if [ "$codigo" -ne 0 ] && printf '%s' "$salida" | grep -qF -e "$esperado"; then
    printf '  ok   %-28s atrapado: %s\n' "$nombre" "$esperado"
  else
    printf '  MAL  %-28s NO se atrapo (codigo %s). Se esperaba: %s\n' "$nombre" "$codigo" "$esperado"
    printf '%s\n' "$salida" | sed 's/^/         /'
    fallos=1
  fi
}

echo 'Arnes del validador de workflows:'

plantar valido.yml VERDE <<YAML
name: valido
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$SHA # v5
      - run: |
          if [ -n "\$HOME" ]; then
            echo hola
          fi
  llama-reutilizable:
    uses: ./.github/workflows/otro.yaml
YAML

plantar sin-sha.yml 'no va fijada por un SHA' <<YAML
name: sin sha
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
YAML

plantar sin-timeout.yml 'sin `timeout-minutes:`' <<YAML
name: sin timeout
on:
  pull_request:
jobs:
  uno:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$SHA
YAML

plantar continue-on-error.yml 'continue-on-error: true' <<YAML
name: puerta que no tumba
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - run: exit 1
YAML

plantar agente-con-bash.yml 'en los argumentos del agente' <<YAML
name: agente con shell
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@$SHA
        with:
          claude_args: |
            --max-turns 10 --allowedTools "Read,Bash(cat *)"
YAML

plantar sin-permisos.yml '--dangerously-skip-permissions' <<YAML
name: agente sin control
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - uses: anthropics/claude-code-action@$SHA
        with:
          claude_args: --dangerously-skip-permissions
YAML

plantar pr-target.yml 'checkout del codigo del PR' <<YAML
name: codigo ajeno con secretos de la base
on:
  pull_request_target:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$SHA
        with:
          ref: \${{ github.event.pull_request.head.sha }}
YAML

plantar extension-mala.yml.bak 'GitHub solo lee .yml y .yaml' <<YAML
name: este archivo no corre
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - run: true
YAML

plantar DEPENDABOT 'Dependabot solo lee' <<YAML
version: 2
updates:
  - package-ecosystem: npm
    directory: /
    schedule:
      interval: weekly
YAML

# Los dos que el validador ya cubria y no tenian arnes.
plantar if-truncado.yml 'delimitadores sin cerrar' <<YAML
name: if truncado
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - if: startsWith(github.event.head_commit.message, 'Merge pull request #')
        run: true
YAML

plantar run-roto.yml 'no es shell valido' <<YAML
name: run roto
on:
  pull_request:
jobs:
  uno:
    timeout-minutes: 5
    runs-on: ubuntu-latest
    steps:
      - run: |
          echo uno
          fi
YAML

echo
if [ "$fallos" -eq 0 ]; then
  echo "Arnes del validador de workflows: $casos caso(s), todos como se esperaba."
else
  echo '::error::El validador de workflows esta ciego a algo que deberia atrapar.'
fi
exit "$fallos"
