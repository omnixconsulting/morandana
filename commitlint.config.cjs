// Conventional Commits. Los mismos prefijos que valida el título del PR, para
// que el hook local y el CI no discrepen.
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // Los mensajes de este portafolio son largos a propósito: explican el modo
    // de falla, no solo el cambio. El límite por defecto de 100 los cortaría.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
