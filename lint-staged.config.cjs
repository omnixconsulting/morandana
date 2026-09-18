/** @type {import('lint-staged').Config} */
module.exports = {
  'src/**/*.{ts,tsx}': 'eslint --fix',
};
