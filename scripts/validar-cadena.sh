#!/usr/bin/env bash
# Validador de cadena de suministro (estándar Meridian, §5.8).
#
# Dependabot cubre CVE publicadas. Esto cubre la otra mitad:
#
#   1. Que ninguna dependencia venga de fuera del registro de npm. Un `resolved`
#      apuntando a un tarball, a un git remoto o a una ruta local se salta la
#      verificación de integridad y no lo mira nadie.
#   2. Que toda entrada del lockfile traiga su hash de integridad.
#   3. Que el conjunto de paquetes con script de instalación no cambie sin que
#      alguien lo note. Un postinstall corre código con los permisos de quien
#      instala, ANTES de que ninguna puerta revise nada.
#
# El CI instala con --ignore-scripts, así que el punto 3 es defensa en
# profundidad: aunque no se ejecuten en CI, sí se ejecutan en la máquina de
# quien clone e instale normal.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec python3 - "$@" <<'PY'
import json, sys, os

CONTRATO = "contracts/scripts-de-instalacion.txt"
fallos = []

try:
    lock = json.load(open("package-lock.json"))
except Exception as e:
    print(f"::error::package-lock.json no parsea: {e}")
    sys.exit(1)

paquetes = lock.get("packages", {})

# --- 1 y 2: procedencia e integridad ---------------------------------------
forasteros, sin_hash = [], []
for ruta, meta in paquetes.items():
    if not ruta or meta.get("link"):        # la raíz y los enlaces de workspace
        continue
    res = meta.get("resolved")
    if res is None:                          # workspaces locales
        continue
    if not res.startswith("https://registry.npmjs.org/"):
        forasteros.append(f"{ruta} ← {res}")
    elif not meta.get("integrity"):
        sin_hash.append(ruta)

if forasteros:
    fallos.append("dependencias fuera del registro de npm: " + ", ".join(forasteros[:5]))
if sin_hash:
    fallos.append("entradas sin hash de integridad: " + ", ".join(sin_hash[:5]))

# --- 3: scripts de instalación ---------------------------------------------
reales = sorted({r.split("node_modules/")[-1] for r, m in paquetes.items() if m.get("hasInstallScript")})

if not os.path.exists(CONTRATO):
    fallos.append(f"falta {CONTRATO}")
else:
    declarados = sorted(
        l.strip() for l in open(CONTRATO)
        if l.strip() and not l.strip().startswith("#")
    )
    nuevos = [p for p in reales if p not in declarados]
    idos   = [p for p in declarados if p not in reales]
    if nuevos:
        fallos.append(
            "paquetes con script de instalación NO declarados: " + ", ".join(nuevos)
            + f" — si es deliberado, agrégalos a {CONTRATO} en el mismo PR")
    if idos:
        fallos.append(
            "declarados que ya no traen script: " + ", ".join(idos)
            + f" — quítalos de {CONTRATO}")

if fallos:
    for f in fallos:
        print(f"::error::{f}")
    sys.exit(1)

print(f"Cadena de suministro: {len(paquetes)} entradas del lockfile, "
      f"todas del registro y con hash · {len(reales)} con script de instalación, declarados.")
PY
