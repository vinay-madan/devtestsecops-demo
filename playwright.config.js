import { defineConfig } from '@playwright/test';

// Juice Shop is started by ./scripts/stage2-dynamic.sh (docker) or run it yourself:
//   docker run --rm -d -p 3000:3000 bkimminich/juice-shop
export default defineConfig({
  testDir: './tests',
  headless: false,
  workers: 1,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'out/playwright' }]],
  use: { baseURL: process.env.BASE_URL ?? 'http://localhost:3000', ignoreHTTPSErrors: true }
});
