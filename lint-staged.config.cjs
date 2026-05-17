module.exports = {
  '*.{ts,js}': ['eslint --fix --max-warnings=0', () => 'vitest related --run'],
  '*.{ts,js,md,json}': ['prettier --write'],
};
