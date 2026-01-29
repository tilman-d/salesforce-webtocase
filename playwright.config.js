// @ts-check
const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
    testDir: './tests',
    fullyParallel: false,
    forbidOnly: !!process.env.CI,
    retries: 0,
    workers: 1,
    reporter: 'list',
    timeout: 120000,
    use: {
        baseURL: 'https://gmailcomdev266-dev-ed.develop.my.salesforce.com',
        trace: 'on-first-retry',
        screenshot: 'on',
        video: 'off',
        headless: true,
        viewport: { width: 1920, height: 1080 },
    },
    projects: [
        {
            name: 'chromium',
            use: { ...devices['Desktop Chrome'] },
        },
    ],
});
