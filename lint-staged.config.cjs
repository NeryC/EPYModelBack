module.exports = {
  '*.{ts,js}': ['eslint --fix --max-warnings=0 --no-warn-ignored', () => 'vitest related --run'],
  '*.{ts,js,md,json}': ['prettier --write'],
};
