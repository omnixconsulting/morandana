## Como probarlo

<!-- Esta sección la pega `dependabot-como-probarlo.yml`. Se edita AQUÍ, no en el
     cuerpo del PR: ahí se pierde en la siguiente tanda. -->

1. **La prueba es el propio workflow.** El job que usa la acción actualizada
   corre en este PR: si termina en verde, la actualización sirve. El sujeto de la
   prueba y la prueba son lo mismo, y por eso no hay nada que ejercitar aparte.
2. `npm run workflows` en local → verde. Comprueba que la acción sigue fijada por
   SHA y no por etiqueta, que actionlint no se queja del YAML, y que zizmor no
   encuentra hallazgos medium o más. **El job de Calidad no corre este script**
   —solo su arnés—, así que es la única vez que alguien lo pasa sobre el diff.
3. **A ojo, y es lo único que una máquina no puede:** que el comentario de versión
   al final de la línea (`# v4.38.2`) corresponda al SHA nuevo. Un SHA correcto
   con un comentario mentiroso pasa todas las puertas, y es lo que después se lee
   para decidir si hay que actualizar.
4. **Si Dependabot abrió un PR por cada subacción del mismo repositorio**
   —`codeql-action/init` y `codeql-action/analyze` de `codeql.yml`, que es el
   caso que sale seguido aquí— van juntos al mismo SHA. Fusionar uno solo las
   deja en versiones distintas, una combinación que el proveedor no garantiza.
