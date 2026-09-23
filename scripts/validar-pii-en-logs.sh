#!/usr/bin/env bash
# Validador de PII en logs (estándar Meridian, §5.8 · LFPDPPP).
#
# «Sin PII en logs, analítica ni mensajes de error» estaba escrito en el
# estándar y no lo comprobaba nada. Era una regla, no una puerta.
#
# QUÉ BUSCA, Y POR QUÉ ESO
# El caso real no es alguien escribiendo `console.log(usuario.email)`. Es más
# sutil: registrar el CUERPO CRUDO de la respuesta de un tercero. Supabase Auth,
# Resend y Anthropic devuelven en sus errores parte de lo que se les mandó —el
# correo del invitado, el destinatario, el prompt— y eso termina en los logs de
# Vercel, que se guardan y los ve cualquiera con acceso al proyecto.
#
# Por eso la lista incluye `body`, `payload`, `data`, `txt` y `resp` junto a los
# nombres obvios de PII: son los nombres que reciben esos cuerpos.
#
# QUÉ NO BUSCA
# Un `console.error('[modulo] falló', e)` con un Error de por medio no es un
# hallazgo, y marcarlo haría que nadie mirara la salida. Por eso se quitan los
# literales de texto antes de comparar: `'[send-email] error'` contiene «email»
# y no es una fuga.

set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec python3 - "$@" <<'PY'
import re, subprocess, sys

# Nombres que suelen contener datos personales, o el cuerpo crudo donde vienen.
SOSPECHOSOS = [
    "body", "payload", "data", "txt", "resp",
    "correo", "email", "mail", "telefono", "phone", "celular",
    "nombre", "apellido", "direccion", "address", "rfc", "curp",
    "cliente", "usuario", "paciente",
]

EXT = (".js", ".jsx", ".mjs", ".cjs", ".ts", ".tsx")
# Rutas que no son código nuestro: copias de referencia, bundles, diseños.
EXCLUIR = ("design/", "node_modules/", "dist/", "build/", ".next/",
           "theme-v7/", "theme-v7-overrides/", "vendor/")

archivos = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout.split()
archivos = [f for f in archivos if f.endswith(EXT) and not any(f.startswith(e) or f"/{e}" in f for e in EXCLUIR)]

# Quita literales de cadena: `'[send-email] error'` contiene «email» y no es PII.
CADENAS = re.compile(r"""(['"`])(?:\\.|(?!\1).)*\1""", re.S)
# `redactar(x)` y `resumenDeRespuesta(x)` son la vía sancionada para registrar
# un cuerpo ajeno: enmascaran correos y teléfonos. Lo que envuelven deja de ser
# un hallazgo — si no, el código ya arreglado seguiría marcado y la puerta
# empujaría a rodearla en vez de a usarla.
REDACTADO = re.compile(r"\b(?:redactar|resumenDeRespuesta)\s*\([^)]*\)")
LLAMADA = re.compile(r"console\.(?:log|info|debug|warn|error)\s*\(")

hallazgos, servidor = [], []

for f in archivos:
    try:
        lineas = open(f, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        continue
    # Los bundles minificados son una sola línea enorme: no son código revisable.
    if any(len(l) > 2000 for l in lineas):
        continue

    en_servidor = f.startswith("api/") or f.startswith("lib/") or "/api/" in f

    for i, linea in enumerate(lineas, 1):
        m = LLAMADA.search(linea)
        if not m:
            continue
        # Solo los argumentos de ESTA llamada: hasta su paréntesis de cierre.
        # Tomar el resto de la línea marcaba código que viene DESPUÉS, como en
        # `console.error('...', e); email = {...}` — un falso positivo, y un
        # validador con falsos positivos es uno que la gente aprende a ignorar.
        resto, prof, fin = linea[m.end():], 1, len(linea)
        for j, ch in enumerate(resto):
            if ch == '(':
                prof += 1
            elif ch == ')':
                prof -= 1
                if prof == 0:
                    fin = j
                    break
        args = REDACTADO.sub("''", CADENAS.sub("''", resto[:fin]))
        encontrados = sorted({s for s in SOSPECHOSOS if s in args.lower()})
        if encontrados:
            hallazgos.append((f, i, ",".join(encontrados), linea.strip()[:100]))
        # En servidor, log/info/debug no tienen lugar: son restos de depuración
        # y suelen volcar objetos enteros. `error` y `warn` sí son operativos.
        if en_servidor and re.match(r"console\.(log|info|debug)\s*\(", linea.strip()):
            servidor.append((f, i, linea.strip()[:100]))

salida = 0
for f, i, cual, txt in hallazgos:
    print(f"::error::{f}:{i} registra «{cual}» — puede llevar datos personales al log: {txt}")
    salida = 1
for f, i, txt in servidor:
    print(f"::error::{f}:{i} console.log/info/debug en código de servidor: {txt}")
    salida = 1

if salida == 0:
    print(f"PII en logs: {len(archivos)} archivos revisados, sin hallazgos.")
sys.exit(salida)
PY
