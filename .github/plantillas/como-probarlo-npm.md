## Como probarlo

<!-- Esta sección la pega `dependabot-como-probarlo.yml`. Se edita AQUÍ, no en el
     cuerpo del PR: ahí se pierde en la siguiente tanda. -->

**Lo que la puerta ya prueba, y no hay que repetir a mano:** procedencia, hashes
de integridad, licencias y scripts de instalación de cada paquete del lockfile
(`npm run cadena`), lint, tipos, build, cabeceras, PII en logs, y las políticas
RLS contra un Postgres real (`supabase/tests/0001_rls.sql`). Todo eso corre en el
job «Lint, tipos, secretos, build y RLS» de este PR.

**Lo que sí necesita a una persona:**

1. Desde un árbol limpio: `rm -rf node_modules && npm ci`. Debe instalar sin
   avisos de `peer`. CI instala con caché de npm y `--ignore-scripts`, así que
   ésta es la única instalación completa desde cero que alguien hace.
2. `npm run verificar` en local → verde. Incluye dos pasos que el job de Calidad
   no corre: `npm run workflows` y `npm run env`.
3. **`@supabase/supabase-js` → el menú y el feed de Instagram de la portada, y
   hay que saber distinguirlos del estático.** `getMenu()` y `getIgPosts()`
   devuelven `null` ante cualquier fallo, y `Landing` cae a los arreglos
   escritos en el código, que tienen el mismo contenido que `seed_menu.sql`. Una
   portada que se ve bien no prueba que Supabase respondió. Para distinguir: con
   `.env.local` apuntando al proyecto (ver `.env.local.example`), `npm run dev`;
   en la tabla `menu_items` poner `is_active = false` en la fila de «Matcha» y
   recargar `http://localhost:3000` → la tarjeta debe desaparecer de la pestaña
   Bebidas. Si sigue ahí, estás viendo el estático. La portada es ISR
   (`revalidate = 300`), así que si no cambia, reinicia el servidor antes de
   concluir que falló. Revertir la fila al terminar.
4. **Las pruebas RLS cubren las políticas; el cliente es la otra mitad.**
   `0001_rls.sql` afirma contra Postgres que `anon` solo ve lo activo y que no
   lee ni escribe `leads` —nombre, correo, teléfono y mensaje de personas
   reales—, y un bump de `supabase-js` no puede mover eso: vive en la base. Lo
   que sí puede mover es lo que `getMenu()` y `getIgPosts()` hacen con ella: el
   `.select()` por nombre de columna, el `.order()` y la forma de `data`.
   Cualquiera de los tres rompiéndose cae en el `catch` y vuelve `null`, o sea el
   mismo síntoma del paso 3. Por eso ese paso es el que vale: si la fila
   desaparece, el camino completo —cliente, PostgREST y política— funciona.
5. **`next`, `react`, `react-dom` → recorrer las dos rutas.** `npm run build &&
   npm start`. En `/`, cambiar las tres pestañas del menú (A.M. / P.M. /
   Bebidas), que son estado de cliente. Abrir `/qr` y recargar ahí: es la única
   ruta que no es la raíz y monta un iframe a la página de pedidos. La consola no
   debe traer errores de hidratación. El banner de cookies debe aparecer y la
   decisión persistir al recargar: eso ejercita el `useSyncExternalStore` de
   `useConsent`, que es lo que un salto de React toca.
6. **`@vercel/analytics`, `@vercel/speed-insights` → en el preview, no en
   local.** En dev piden `script.debug.js`, que el servidor local no sirve; ese
   404 es lo esperado y no prueba nada. En la URL de preview del check de Vercel,
   la pestaña de red debe mostrar `/_vercel/insights/script.js` y
   `/_vercel/speed-insights/script.js` en 200. No pasan por el consentimiento:
   `layout.tsx` los monta sin condición, a diferencia de GTM.
7. **Si la tabla toca un hook de git**, comprobarlo en el acto:
   - `@commitlint/*` → un mensaje sin tipo debe ser rechazado; con tipo, pasar.
   - `lint-staged`, `husky` → dejar un `import` sin usar en un `.tsx` de `src/` y
     hacer commit: el hook debe quitarlo con `eslint --fix` antes de guardarlo.
8. **Lo que no aparece arriba no tiene paso propio** a propósito. Un paquete de
   `devDependencies` que solo alimenta build, lint o tipos ya queda ejercitado
   por el paso 2; inventarle un paso es ruido que nadie corre.

> Si el PR lleva varios días abierto, pedir `@dependabot rebase` antes de
> fusionar: el lockfile tiene que salir del `main` de ahora.
