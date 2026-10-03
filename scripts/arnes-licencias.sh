#!/usr/bin/env bash
# Arnés del chequeo de licencias de `validar-cadena.sh` (§5.7).
#
# Un detector que dice «ninguna» es indistinguible de uno roto. Esto rompe cada
# chequeo a propósito, sobre copias del lockfile y del contrato, y comprueba que
# el validador falle CON SU MENSAJE. No toca nada versionado.
#
# **Se configura solo desde el lockfile de este repo.** No nombra paquetes a
# mano: el archivo es idéntico en los siete repos y cada uno tiene dependencias
# distintas —`medicarmen` no trae sharp, el CRM y el portal no tienen ninguna
# excepción—. Los casos que este repo no puede ejercitar se declaran OMITIDOS,
# nunca como verdes: un caso que no corrió no es un caso que pasó.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAIZ="$PWD"
VALIDADOR="$RAIZ/scripts/validar-cadena.sh"
CONTRATO="$RAIZ/contracts/licencias-excepciones.txt"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fallos=0
omitidos=0
caso() {
  local nombre="$1" espera="$2" esperado="$3" dir="$4"
  local salida codigo
  salida="$("$VALIDADOR" "$dir" 2>&1)"; codigo=$?
  if [ "$espera" = "falla" ] && [ "$codigo" -eq 0 ]; then
    echo "  ✗ $nombre — el validador PASÓ y debía fallar"; fallos=$((fallos+1)); return
  fi
  if [ "$espera" = "pasa" ] && [ "$codigo" -ne 0 ]; then
    echo "  ✗ $nombre — el validador falló y debía pasar:"; echo "$salida" | sed 's/^/      /'
    fallos=$((fallos+1)); return
  fi
  if [ -n "$esperado" ] && ! printf '%s' "$salida" | grep -qF -e "$esperado"; then
    echo "  ✗ $nombre — falló, pero no por lo esperado («$esperado»):"
    echo "$salida" | sed 's/^/      /'; fallos=$((fallos+1)); return
  fi
  echo "  ✓ $nombre"
}
omitir() { echo "  ⊘ $1 — OMITIDO: $2"; omitidos=$((omitidos+1)); }

fixture() {
  local d="$TMP/$1"; mkdir -p "$d/contracts"
  cp "$RAIZ/package-lock.json" "$d/package-lock.json"
  cp "$RAIZ/contracts/scripts-de-instalacion.txt" "$d/contracts/"
  cp "$CONTRATO" "$d/contracts/"
  printf '%s' "$d"
}

# --- Qué puede ejercitar este repo, leído de sus propios archivos -----------
# Un paquete con licencia permisiva, para cambiársela. Y, si hay excepciones,
# una fila exacta y una de patrón con el paquete al que cubren.
# Emite tres líneas: paquete permisivo, fila exacta, paquete cubierto por un
# patrón. Vacías cuando este repo no puede ejercitar ese caso.
DATOS="$TMP/datos.txt"
python3 - "$RAIZ" > "$DATOS" <<'PY'
import json, re, sys, pathlib
raiz = pathlib.Path(sys.argv[1])
PERM = {"MIT","MIT-0","ISC","Apache-2.0","BSD-2-Clause","BSD-3-Clause","0BSD",
        "BlueOak-1.0.0","CC0-1.0","CC-BY-4.0","Unlicense","Python-2.0"}

def partes(expr):
    limpio = expr.replace("(", " ").replace(")", " ")
    return [p.strip() for p in re.split(r"\s+(?:OR|AND)\s+", limpio) if p.strip()]

def permisiva(expr):
    ps = partes(expr)
    return bool(ps) and all(p in PERM for p in ps)

lock = json.load(open(raiz / "package-lock.json"))
deps = {}
for ruta, meta in lock["packages"].items():
    if not ruta or meta.get("link") or "node_modules/" not in ruta:
        continue
    deps[ruta.split("node_modules/")[-1]] = meta.get("license")

permisivo = ""
for nombre in sorted(deps):
    lic = deps[nombre]
    if isinstance(lic, str) and permisiva(lic) and "/" not in nombre:
        permisivo = nombre
        break

filas = []
contrato = raiz / "contracts/licencias-excepciones.txt"
if contrato.exists():
    for linea in contrato.read_text().splitlines():
        linea = linea.strip()
        if not linea or linea.startswith("#"):
            continue
        campos = re.split(r"\s{2,}", linea)
        if len(campos) >= 3:
            filas.append((campos[0].strip(), campos[1].strip()))

def empata(patron, paquete):
    if patron.endswith("*"):
        return paquete.startswith(patron[:-1])
    return paquete == patron

fila_exacta = ""
for patron, lic in filas:
    if not patron.endswith("*") and deps.get(patron) == lic:
        fila_exacta = patron
        break

patron_paquete = ""
for patron, lic in filas:
    if not patron.endswith("*"):
        continue
    for paquete in sorted(deps):
        if empata(patron, paquete) and deps[paquete] == lic:
            patron_paquete = paquete
            break
    if patron_paquete:
        break

print(permisivo)
print(fila_exacta)
print(patron_paquete)
PY
if [ ! -s "$DATOS" ]; then
  echo "::error::el arnés no pudo leer el lockfile ni el contrato; no midió nada" >&2
  exit 1
fi
PERMISIVO="$(sed -n 1p "$DATOS")"
FILA_EXACTA="$(sed -n 2p "$DATOS")"
PATRON_PAQUETE="$(sed -n 3p "$DATOS")"

echo "Arnés de licencias:"

# 0. El árbol intacto pasa. Si este falla, los demás no prueban nada.
caso "el repo tal como está pasa" pasa "" "$(fixture intacto)"

cambia_licencia() {  # $1 dir, $2 paquete, $3 licencia nueva ('' = quitarla)
  python3 - "$1" "$2" "${3:-}" <<'PY'
import json, sys
d, paquete, lic = sys.argv[1], sys.argv[2], sys.argv[3]
f = d + "/package-lock.json"
lock = json.load(open(f))
for ruta, meta in lock["packages"].items():
    if ruta.endswith("node_modules/" + paquete):
        if lic: meta["license"] = lic
        else: meta.pop("license", None)
        break
else:
    sys.exit(f"el fixture no encontró {paquete}")
json.dump(lock, open(f, "w"))
PY
}

# 1. Una licencia prohibida en una dependencia.
if [ -n "$PERMISIVO" ]; then
  d="$(fixture agpl)"; cambia_licencia "$d" "$PERMISIVO" "AGPL-3.0"
  caso "una dependencia AGPL falla, nombrándola" falla "$PERMISIVO (AGPL-3.0)" "$d"
  # 4. Una dependencia sin licencia en el lockfile.
  d="$(fixture sin_licencia)"; cambia_licencia "$d" "$PERMISIVO" ""
  caso "una dependencia sin licencia falla" falla "sin licencia declarada" "$d"
else
  omitir "licencia prohibida" "no hay dependencias en el lockfile"
  omitir "dependencia sin licencia" "no hay dependencias en el lockfile"
fi

# 2. Una excepción borrada deja de cubrir a su paquete.
if [ -n "$FILA_EXACTA" ]; then
  d="$(fixture sin_fila)"
  grep -v "^$FILA_EXACTA  " "$d/contracts/licencias-excepciones.txt" > "$d/contracts/.t" \
    && mv "$d/contracts/.t" "$d/contracts/licencias-excepciones.txt"
  caso "borrar la excepción de $FILA_EXACTA falla" falla "$FILA_EXACTA (" "$d"
else
  omitir "borrar una excepción" "este repo no tiene excepciones de fila exacta"
fi

# 3. Una excepción que ya no empata con nada.
d="$(fixture muerta)"
printf 'paquete-que-no-existe  MPL-2.0  excepción de prueba\n' >> "$d/contracts/licencias-excepciones.txt"
caso "una excepción muerta falla" falla "paquete-que-no-existe" "$d"

# 5. La licencia del patrón es exacta: misma familia, otra licencia, falla.
if [ -n "$PATRON_PAQUETE" ]; then
  d="$(fixture familia_otra_licencia)"; cambia_licencia "$d" "$PATRON_PAQUETE" "SSPL-1.0"
  caso "el patrón no tapa otra licencia de la misma familia" falla "SSPL-1.0" "$d"
else
  omitir "patrón con otra licencia" "este repo no tiene excepciones con patrón"
fi

# 6. El contrato ausente falla cerrado.
d="$(fixture sin_contrato)"; rm "$d/contracts/licencias-excepciones.txt"
caso "falta el contrato: falla cerrado" falla "falta" "$d"

# 7. Tres columnas: una fila con dos falla en vez de ignorarse.
d="$(fixture malformado)"
printf 'solo-dos-columnas  MIT\n' >> "$d/contracts/licencias-excepciones.txt"
caso "una fila sin la tercera columna falla" falla "mal formado" "$d"

echo
if [ "$fallos" -gt 0 ]; then
  echo "::error::Arnés de licencias: $fallos caso(s) en rojo."
  exit 1
fi
if [ "$omitidos" -gt 0 ]; then
  echo "Arnés de licencias: en verde, con $omitidos caso(s) OMITIDO(S) por no aplicar a este repo."
else
  echo "Arnés de licencias: todos los casos en verde."
fi
