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
  # `--output-format json` ES OBLIGATORIO DESDE EL CLI 2.11x
  #
  # Hasta la 2.109 este comando emitia JSON por omision. Despues pasa a imprimir
  # una tabla, el `grep` de abajo no encuentra nada y el detector reporta «el
  # chequeo NO corrio»: falla ruidoso, que es lo correcto, pero quedo inservible
  # sin que nadie lo notara hasta el 8-oct-2026 --justo cuando se necesitaba
  # para decidir si aplicar cuatro migraciones--.
  #
  # La forma del JSON NO cambio: sigue siendo {"migrations":[{local,remote,time}]}.
  # Lo que cambio fue el default. Por eso el arnes de parseo seguia en verde: la
  # unica linea rota era esta, y era la unica que no cubria.
  #
  # El stderr se guarda en vez de tirarse, para que el mensaje de error pueda
  # decir QUE paso en lugar de solo que algo paso.
  errores=$(mktemp); trap 'rm -f "$errores"' EXIT
  crudo=$(supabase migration list --linked --output-format json 2>"$errores")
  salida=$(printf '%s' "$crudo" | grep -o '{"migrations":.*}')
  if [ -z "$salida" ]; then
    echo '::error::No se pudo leer el estado de produccion. El chequeo NO corrio.'
    echo '  No es lo mismo que «sin deriva»: puede haber migraciones sin aplicar.'
    if [ -n "$crudo" ]; then
      echo '  El CLI contesto algo que no es el JSON esperado. Si cambio su formato de'
      echo '  salida otra vez, la bandera `--output-format json` de este script es lo'
      echo '  primero que hay que revisar. Primera linea de lo que devolvio:'
      printf '%s\n' "$crudo" | head -1 | sed 's/^/    /'
    fi
    if [ -s "$errores" ]; then
      echo '  stderr del CLI:'
      sed 's/^/    /' "$errores"
    fi
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
