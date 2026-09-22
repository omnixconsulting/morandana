#!/usr/bin/env bash
# Validador de cabeceras de seguridad (estándar Meridian, §5.8).
#
# Las cabeceras se declaran en `vercel.json` o en `next.config.*`, y en los dos
# casos un recorte distraído las borra sin que nada se queje: dejan de emitirse
# en silencio. Si la regla se puede escribir como texto literal, es un validador
# y no una convención.
#
# Qué NO hace: comprobar que el borde las sirva. Eso se ve con `curl -I` contra
# el despliegue. Aquí se fija que la declaración no desaparezca del repo.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec python3 - "$@" <<'PY'
import json, os, re, sys, glob

ESPERADAS = {
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "strict-origin-when-cross-origin",
    "X-Frame-Options": None,      # DENY o SAMEORIGIN según si el sitio se embebe
    "Permissions-Policy": None,   # el valor puede crecer; basta con que exista
}
DIRECTIVAS = ["default-src", "base-uri", "object-src", "frame-ancestors",
              "script-src", "connect-src", "form-action"]

fallos, fuente, presentes, csp = [], None, {}, None

# --- Forma 1: vercel.json con reglas de headers -----------------------------
if os.path.exists("vercel.json"):
    try:
        d = json.load(open("vercel.json"))
    except Exception as e:
        print(f"::error::vercel.json no parsea: {e}")
        sys.exit(1)
    for h in d.get("headers", []):
        claves = {k["key"]: k["value"] for k in h.get("headers", [])}
        if any(c in claves for c in ESPERADAS):
            fuente, presentes = "vercel.json", claves
            break

# --- Forma 2: next.config.* (se lee como texto) -----------------------------
if fuente is None:
    for cfg in glob.glob("next.config.*") + glob.glob("apps/web/next.config.*"):
        txt = open(cfg).read()
        if "async headers()" not in txt and "headers()" not in txt:
            continue
        fuente = cfg
        for clave in ESPERADAS:
            m = re.search(r'key:\s*["\']' + re.escape(clave) + r'["\']\s*,\s*value:\s*["\']([^"\']*)["\']', txt)
            if m:
                presentes[clave] = m.group(1)
        m = re.search(r'["\']Content-Security-Policy(-Report-Only)?["\']', txt)
        if m:
            presentes["Content-Security-Policy" + (m.group(1) or "")] = ""
            # La CSP se arma en un arreglo de directivas; se valida sobre el texto.
            csp = txt
        break

if fuente is None:
    print("::error::no encuentro dónde se declaran las cabeceras (vercel.json ni next.config.*)")
    sys.exit(1)

for clave, valor in ESPERADAS.items():
    if clave not in presentes:
        fallos.append(f"falta la cabecera {clave}")
    elif valor is not None and presentes[clave] != valor:
        fallos.append(f"{clave} vale «{presentes[clave]}», se esperaba «{valor}»")

if csp is None:
    csp = presentes.get("Content-Security-Policy") or presentes.get("Content-Security-Policy-Report-Only")

reporta_solo = "Content-Security-Policy-Report-Only" in presentes
if not (csp or reporta_solo):
    fallos.append("no hay Content-Security-Policy ni su variante Report-Only")
else:
    for dir_ in DIRECTIVAS:
        if dir_ not in (csp or ""):
            fallos.append(f"la CSP no declara {dir_}")
    # Un 'unsafe-inline' en script-src vacía de sentido a la CSP frente al XSS
    # que es su razón de existir. En style-src es aceptable y por eso está.
    #
    # OJO con el patrón, que ya falló una vez: la directiva lleva sus valores
    # entre comillas SIMPLES ('self', 'unsafe-inline'). Un regex que excluya la
    # comilla simple corta el tramo en 'self' y nunca llega a ver lo que viene
    # a buscar — pasa en verde justo cuando debería fallar. Se aísla por el
    # delimitador real de cada forma: `;` en la cadena única de vercel.json, y
    # la comilla que cierra el elemento del arreglo en next.config.*.
    tramos = [t for t in (csp or "").split(";") if t.strip().startswith("script-src")]
    tramos += re.findall(r'"(script-src[^"]*)"', csp or "")
    tramos += re.findall(r"'(script-src[^']*)'", csp or "")
    for tramo in tramos:
        if "'unsafe-inline'" in tramo or "'unsafe-eval'" in tramo:
            fallos.append("script-src permite 'unsafe-inline'/'unsafe-eval': la CSP deja de proteger contra XSS")
            break

if fallos:
    for f in dict.fromkeys(fallos):
        print(f"::error::{f}")
    sys.exit(1)

modo = "Report-Only (mide, no bloquea)" if reporta_solo else "activa"
print(f"Cabeceras de seguridad en {fuente}: {len(ESPERADAS)} presentes · CSP {modo}.")
PY
