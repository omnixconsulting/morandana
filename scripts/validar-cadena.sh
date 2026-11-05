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
#      que nadie negoció. Estos repos se entregan; una AGPL, SSPL o BUSL en el
#      árbol es un problema legal que no detecta ningún CVE ni ningún hash.
#      El dato ya está en el lockfile, así que el chequeo no consulta la red.
#
# El CI instala con --ignore-scripts, así que el punto 3 es defensa en
# profundidad: aunque no se ejecuten en CI, sí se ejecutan en la máquina de
# quien clone e instale normal.
#
# TODOS LOS LOCKFILES, NO SOLO EL DE LA RAÍZ
# Un repo puede tener más de un sitio de instalación que no son workspaces de
# npm, sino instalaciones independientes: `jerrymedrano` tiene la raíz y
# `bni-app/`, y `medicarmen` tiene la raíz y `scripts/docx/`. Mirar solo la raíz
# dejaba el segundo lockfile sin revisar, y así estuvo el de `scripts/docx` de
# medicarmen —con dos licencias no permisivas— hasta el 5-nov-2026.
#
# Por eso el validador RECORRE el árbol. Si mañana aparece un tercer sitio queda
# cubierto sin que nadie se acuerde de agregarlo: lo que falla es el contrato
# ausente, no el lockfile sin revisar.
#
# Quién instala cada uno es lo que dice dónde se ejecutaría un postinstall: el de
# la raíz lo instalan el CI (con --ignore-scripts) y el despliegue; los demás, no
# necesariamente —`npm ci` solo ve la raíz—. Todos los instala quien clone y corra
# `npm install` normal, sin --ignore-scripts, que es la máquina de desarrollo.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)" || exit 1

exec python3 - "$@" <<'PY'
import json, re, sys, os

# Costura de prueba: con un directorio como primer argumento, valida ESE árbol en
# vez del repo. Es como `arnes-licencias.sh` rompe cada chequeo a propósito (§5.7)
# sin tocar el lockfile versionado. Sin argumento, el repo.
RAIZ = sys.argv[1] if len(sys.argv) > 1 else "."
try:
    os.chdir(RAIZ)
except OSError as e:
    print(f"::error::no pude entrar a {RAIZ}: {e}")
    sys.exit(1)

# Expresiones SPDX que no necesitan excepción. Permisivas: no imponen nada al
# cliente más allá de conservar el aviso de copyright.
PERMISIVAS = {
    "MIT", "MIT-0", "ISC", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause",
    "0BSD", "BlueOak-1.0.0", "CC0-1.0", "CC-BY-4.0", "Unlicense", "Python-2.0",
}

fallos = []
informe = []


def contrato_de(dir_rel, base):
    """`contracts/<base>.txt` para la raíz; `-<dir>` para los demás.

    La raíz conserva el nombre canónico del estándar a propósito: así el diff
    contra los otros repos del portafolio sigue siendo legible.
    """
    if dir_rel in ("", "."):
        return f"contracts/{base}.txt"
    return "contracts/%s-%s.txt" % (base, dir_rel.strip("/").replace("/", "-"))


def permisiva(expr):
    """Toda parte de una expresión `X OR Y` / `X AND Y` tiene que ser permisiva.

    Con AND basta que una parte no lo sea para que obligue, y con OR podríamos
    quedarnos con la permisiva, pero no distinguimos: pedir la excepción hace
    que alguien lo lea. Es el lado seguro.
    """
    partes = re.split(r"\s+(?:OR|AND)\s+", expr.replace("(", " ").replace(")", " "))
    partes = [p.strip() for p in partes if p.strip()]
    return bool(partes) and all(p in PERMISIVAS for p in partes)


def empata(patron, paquete):
    return paquete == patron if not patron.endswith("*") else paquete.startswith(patron[:-1])


def revisar(lock_rel):
    dir_rel = os.path.dirname(lock_rel)
    etiqueta = lock_rel
    contrato = contrato_de(dir_rel, "scripts-de-instalacion")
    licencias = contrato_de(dir_rel, "licencias-excepciones")

    try:
        lock = json.load(open(lock_rel))
    except Exception as e:
        fallos.append(f"{etiqueta} no parsea: {e}")
        return

    paquetes = lock.get("packages", {})

    # --- 1 y 2: procedencia e integridad -----------------------------------
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
        fallos.append(f"{etiqueta}: dependencias fuera del registro de npm: "
                      + ", ".join(forasteros[:5]))
    if sin_hash:
        fallos.append(f"{etiqueta}: entradas sin hash de integridad: "
                      + ", ".join(sin_hash[:5]))

    # --- 3: scripts de instalación -----------------------------------------
    reales = sorted({r.split("node_modules/")[-1]
                     for r, m in paquetes.items() if m.get("hasInstallScript")})

    if not os.path.exists(contrato):
        fallos.append(f"{etiqueta}: falta {contrato} — créalo aunque quede vacío, "
                      "es lo que convierte un postinstall nuevo en un diff")
    else:
        declarados = sorted(
            l.strip() for l in open(contrato)
            if l.strip() and not l.strip().startswith("#")
        )
        nuevos = [p for p in reales if p not in declarados]
        idos   = [p for p in declarados if p not in reales]
        if nuevos:
            fallos.append(
                f"{etiqueta}: paquetes con script de instalación NO declarados: "
                + ", ".join(nuevos)
                + f" — si es deliberado, agrégalos a {contrato} en el mismo PR")
        if idos:
            fallos.append(
                f"{etiqueta}: declarados que ya no traen script: " + ", ".join(idos)
                + f" — quítalos de {contrato}")

    # --- 4: licencias ------------------------------------------------------
    # Las dependencias reales: paquete -> expresión de licencia. Los workspaces
    # del propio repo no son dependencias (no traen `node_modules/` en la ruta).
    deps = {}
    for ruta, meta in paquetes.items():
        if not ruta or meta.get("link") or "node_modules/" not in ruta:
            continue
        deps[ruta.split("node_modules/")[-1]] = meta.get("license")

    con_excepcion = 0
    if not os.path.exists(licencias):
        fallos.append(f"{etiqueta}: falta {licencias} — créalo aunque quede vacío, "
                      "es lo que convierte una licencia nueva que obliga en un diff")
    else:
        excepciones = []   # (patrón, licencia exacta, línea)
        malformadas = []
        for n, linea in enumerate(open(licencias), 1):
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
                f"{etiqueta}: {licencias} mal formado (hacen falta tres columnas "
                "separadas por dos espacios o más): " + "; ".join(malformadas))

        usadas, sin_licencia, prohibidas = set(), [], []
        for paquete, expr in sorted(deps.items()):
            if not isinstance(expr, str) or not expr.strip():
                sin_licencia.append(paquete)
                continue
            if permisiva(expr):
                continue
            con_excepcion += 1
            cubierta = [(p, l, n) for p, l, n in excepciones
                        if empata(p, paquete) and l == expr]
            if cubierta:
                usadas.update(n for _, _, n in cubierta)
            else:
                prohibidas.append(f"{paquete} ({expr})")

        if sin_licencia:
            fallos.append(
                f"{etiqueta}: dependencias sin licencia declarada en el lockfile: "
                + ", ".join(sin_licencia[:5])
                + " — sin ese dato no se puede afirmar que sean distribuibles")
        if prohibidas:
            fallos.append(
                f"{etiqueta}: licencias fuera de la lista permisiva y sin excepción: "
                + ", ".join(prohibidas[:5])
                + f" — si es deliberado, agrégalas a {licencias} con la cadena SPDX exacta")

        muertas = [f"{p} ({l}), línea {n}" for p, l, n in excepciones if n not in usadas]
        if muertas:
            fallos.append(
                f"{etiqueta}: excepciones de licencia que ya no empatan con ningún "
                "paquete: " + ", ".join(muertas)
                + f" — quítalas de {licencias}; una excepción muerta es una revisión "
                "que nadie volvió a hacer")

    informe.append(
        f"  {etiqueta}: {len(paquetes)} entradas, todas del registro y con hash · "
        f"{len(reales)} con script de instalación, declarados · {len(deps)} "
        f"dependencias, {len(deps) - con_excepcion} permisivas y {con_excepcion} "
        "con excepción declarada.")


# --- descubrimiento ---------------------------------------------------------
lockfiles = []
for raiz, dirs, archivos in os.walk("."):
    # `.claude` trae los worktrees que crea la app, cada uno con su propia copia
    # de los lockfiles. Sin podarlo, bastaba con que existiera un worktree para
    # que este validador exigiera contratos de rutas que solo viven en esta
    # máquina — y como el hook de commit corre la puerta, eso bloqueaba TODOS
    # los commits locales del repo hasta borrar el worktree (oct-2026).
    dirs[:] = [d for d in dirs if d not in (".git", "node_modules", ".vercel", ".claude")]
    if "package-lock.json" in archivos:
        lockfiles.append(os.path.normpath(os.path.join(raiz, "package-lock.json")))
lockfiles.sort()

if not lockfiles:
    print("::error::no hay ningún package-lock.json — si el repo dejó de tener "
          "dependencias, quita esta puerta a propósito")
    sys.exit(1)

for lock in lockfiles:
    revisar(lock)

if fallos:
    for f in fallos:
        print(f"::error::{f}")
    sys.exit(1)

print(f"Cadena de suministro: {len(lockfiles)} lockfile(s).")
print("\n".join(informe))
PY
