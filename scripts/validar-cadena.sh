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
#   4. Que ninguna dependencia traiga una licencia que obligue al cliente a algo
#      que nadie negoció. Este repo se entrega; una AGPL, SSPL o BUSL en el
#      árbol es un problema legal que no detecta ningún CVE ni ningún hash.
#      El dato ya está en el lockfile, así que el chequeo no consulta la red.
#
# El CI instala con --ignore-scripts, así que el punto 3 es defensa en
# profundidad: aunque no se ejecuten en CI, sí se ejecutan en la máquina de
# quien clone e instale normal.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec python3 - "$@" <<'PY'
import json, re, sys, os

# Costura de prueba: con un directorio como primer argumento, valida ESE árbol
# en vez del repo. Es como `arnes-licencias.sh` rompe cada chequeo a propósito
# (§5.7) sin tocar el lockfile versionado. Sin argumento, el repo.
RAIZ = sys.argv[1] if len(sys.argv) > 1 else "."

CONTRATO = os.path.join(RAIZ, "contracts/scripts-de-instalacion.txt")
LICENCIAS = os.path.join(RAIZ, "contracts/licencias-excepciones.txt")
LOCKFILE = os.path.join(RAIZ, "package-lock.json")

# Expresiones SPDX que no necesitan excepción. Permisivas: no imponen nada al
# cliente más allá de conservar el aviso de copyright.
PERMISIVAS = {
    "MIT", "MIT-0", "ISC", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause",
    "0BSD", "BlueOak-1.0.0", "CC0-1.0", "CC-BY-4.0", "Unlicense", "Python-2.0",
}
fallos = []

try:
    lock = json.load(open(LOCKFILE))
except Exception as e:
    print(f"::error::{LOCKFILE} no parsea: {e}")
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

# --- 4: licencias ----------------------------------------------------------
def permisiva(expr):
    """Toda parte de una expresión `X OR Y` / `X AND Y` tiene que ser permisiva.

    Con AND basta que una parte no lo sea para que obligue, y con OR podríamos
    quedarnos con la permisiva, pero no distinguimos: pedir la excepción hace
    que alguien lo lea. Es el lado seguro.
    """
    partes = re.split(r"\s+(?:OR|AND)\s+", expr.replace("(", " ").replace(")", " "))
    partes = [p.strip() for p in partes if p.strip()]
    return bool(partes) and all(p in PERMISIVAS for p in partes)

# Las dependencias reales: paquete -> expresión de licencia. Los workspaces del
# propio repo no son dependencias (no traen `node_modules/` en la ruta).
deps = {}
for ruta, meta in paquetes.items():
    if not ruta or meta.get("link") or "node_modules/" not in ruta:
        continue
    deps[ruta.split("node_modules/")[-1]] = meta.get("license")

if not os.path.exists(LICENCIAS):
    fallos.append(f"falta {LICENCIAS}")
else:
    excepciones = []   # (patrón, licencia exacta, línea)
    malformadas = []
    for n, linea in enumerate(open(LICENCIAS), 1):
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        campos = re.split(r"\s{2,}", linea)
        if len(campos) < 3:
            malformadas.append(f"línea {n}: {linea}")
            continue
        excepciones.append((campos[0].strip(), campos[1].strip(), n))

    if malformadas:
        fallos.append(
            f"{LICENCIAS} mal formado (hacen falta tres columnas separadas por "
            "dos espacios o más): " + "; ".join(malformadas))

    def empata(patron, paquete):
        return paquete == patron if not patron.endswith("*") else paquete.startswith(patron[:-1])

    usadas, sin_licencia, prohibidas = set(), [], []
    for paquete, expr in sorted(deps.items()):
        if not isinstance(expr, str) or not expr.strip():
            sin_licencia.append(paquete)
            continue
        if permisiva(expr):
            continue
        cubierta = [(p, l, n) for p, l, n in excepciones if empata(p, paquete) and l == expr]
        if cubierta:
            usadas.update(n for _, _, n in cubierta)
        else:
            prohibidas.append(f"{paquete} ({expr})")

    if sin_licencia:
        fallos.append(
            "dependencias sin licencia declarada en el lockfile: "
            + ", ".join(sin_licencia[:5])
            + " — sin ese dato no se puede afirmar que sean distribuibles")
    if prohibidas:
        fallos.append(
            "licencias fuera de la lista permisiva y sin excepción: "
            + ", ".join(prohibidas[:5])
            + f" — si es deliberado, agrégalas a {LICENCIAS} con la cadena SPDX exacta")

    muertas = [f"{p} ({l}), línea {n}" for p, l, n in excepciones if n not in usadas]
    if muertas:
        fallos.append(
            "excepciones de licencia que ya no empatan con ningún paquete: "
            + ", ".join(muertas)
            + f" — quítalas de {LICENCIAS}; una excepción muerta es una revisión que nadie volvió a hacer")

if fallos:
    for f in fallos:
        print(f"::error::{f}")
    sys.exit(1)

con_excepcion = sum(1 for p, e in deps.items() if isinstance(e, str) and e.strip() and not permisiva(e))
print(f"Cadena de suministro: {len(paquetes)} entradas del lockfile, "
      f"todas del registro y con hash · {len(reales)} con script de instalación, declarados.")
print(f"Licencias: {len(deps)} dependencias · {len(deps) - con_excepcion} permisivas · "
      f"{con_excepcion} con excepción declarada.")
PY
