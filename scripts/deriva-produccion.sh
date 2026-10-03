#!/usr/bin/env bash
# ¿Producción tiene aplicadas todas las migraciones del repo?
#
# POR QUE EXISTE
# Las pruebas de base de datos corren contra un Postgres que el CI levanta con
# TODAS las migraciones del repo. Si una no se aplico en produccion, la prueba
# pasa igual. Es un punto ciego por construccion, y ya se materializo tres veces:
#
#   - `morandana`, 22-sep al 3-oct-2026: `20260922120000_privilegios_explicitos`
#     once dias sin aplicar. Mientras tanto, cualquiera con la llave `anon` —que
#     viaja en el bundle del navegador— podia insertar en `leads`. La prueba
#     `0001_rls.sql` exige justo que ese insert falle, y pasaba en CI.
#   - Las dos migraciones de seguridad del CRM de sep-2026, dias sin aplicar.
#     Mientras tanto la llave `anon` podia leer el directorio del personal.
#   - El deploy de `shikomi`, que nunca ha funcionado.
#
# Las tres se encontraron por casualidad. Esto las encuentra en un minuto.
#
# SOLO LEE. No aplica nada: aplicar sigue siendo una decision humana, y esa
# separacion es deliberada. Un detector que ademas aplica es un deploy.
#
# NO VA EN `npm run verificar`. La Puerta 1 corre sin red y sin credenciales de
# produccion; esto necesita las dos. Se corre a mano, y mas adelante por cron.
set -uo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Semilla de prueba: con un archivo como argumento se evalua ese JSON en vez de
# consultar produccion. Es como se comprueba que el detector detecta, sin tocar
# ninguna base. Ver el arnes al final de este archivo.
FIXTURE="${1:-}"

if [ -n "$FIXTURE" ]; then
  salida=$(cat "$FIXTURE")
else
  if [ ! -f supabase/.temp/project-ref ]; then
    echo '::error::Este repo NO esta enlazado a un proyecto de Supabase en esta maquina.'
    echo '  El chequeo no corrio, que no es lo mismo que «sin deriva». Enlazalo con'
    echo '  `supabase link --project-ref <ref>` y vuelve a correrlo.'
    exit 1
  fi
  salida=$(supabase migration list --linked 2>/dev/null | grep -o '{"migrations":.*}')
  if [ -z "$salida" ]; then
    echo '::error::No se pudo leer el estado de produccion. El chequeo NO corrio.'
    exit 1
  fi
fi

faltantes=$(printf '%s' "$salida" | node -e '
  let e=""; process.stdin.on("data",d=>e+=d).on("end",()=>{
    const m = JSON.parse(e).migrations || [];
    const sin = m.filter(x => x.local && !x.remote).map(x => x.local);
    const soloRemotas = m.filter(x => !x.local && x.remote).map(x => x.remote);
    if (soloRemotas.length) console.log("REMOTA_SIN_LOCAL " + soloRemotas.join(" "));
    if (sin.length) console.log("SIN_APLICAR " + sin.join(" "));
    console.log("TOTAL " + m.length);
  });
')

total=$(printf '%s' "$faltantes" | awk '/^TOTAL/{print $2}')
sin=$(printf '%s' "$faltantes" | awk '/^SIN_APLICAR/{$1=""; print}')
remotas=$(printf '%s' "$faltantes" | awk '/^REMOTA_SIN_LOCAL/{$1=""; print}')

fallos=0

if [ -n "$remotas" ]; then
  # Al reves que lo anterior: produccion tiene algo que el repo no. Suele ser un
  # cambio aplicado a mano desde el dashboard, que es justo lo que adrs/0007 del
  # CRM documenta como deuda.
  echo "::warning::Produccion tiene migraciones que NO estan en el repo:$remotas"
  echo '  Revisa si fue un cambio aplicado a mano. El repo deberia ser la fuente.'
fi

if [ -n "$sin" ]; then
  echo "::error::Migraciones del repo SIN APLICAR en produccion:$sin"
  echo '  Produccion no es lo que el repo dice que es, y las pruebas de CI no lo'
  echo '  ven: corren contra una base levantada con todas las migraciones.'
  echo '  Aplicar con `supabase db push` desde main, despues de revisar que hace'
  echo '  cada una.'
  fallos=1
fi

[ "$fallos" -eq 0 ] && [ -z "$remotas" ] && echo "Deriva de produccion: ninguna. $total migraciones, todas aplicadas."
exit "$fallos"
