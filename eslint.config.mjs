import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    // Un arbol de trabajo anidado es OTRO checkout: su codigo lo revisa su
    // propia puerta, y su `.next` es build ajena. Sin esto, basta que alguien
    // haya corrido `next build` en `.claude/worktrees/*` para que la puerta 1
    // de este arbol salga en rojo con 4000 problemas que no son de su diff
    // (medido el 21-oct-2026: 221 errores, todos de chunks minificados).
    ".claude/worktrees/**",
    // `.next/**` solo ancla en la raiz; esto cubre cualquier profundidad.
    "**/.next/**",
  ]),
]);

export default eslintConfig;
