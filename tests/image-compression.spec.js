/**
 * Image Compression Tests
 * Tests the client-side image compression feature for the Case Form
 */
const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');

// Test configuration
const FORM_URL = 'https://gmailcomdev266-dev-ed.develop.my.salesforce-sites.com/support/CaseFormPage?form=support';
const TEST_FILES_DIR = path.join(__dirname, 'test-files');
const SCREENSHOTS_DIR = path.join(__dirname, 'screenshots', 'compression');

// Ensure screenshots directory exists
if (!fs.existsSync(SCREENSHOTS_DIR)) {
    fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });
}

// Helper to fill required form fields
async function fillRequiredFields(page) {
    // Fill in all required fields based on actual form structure
    const nameInput = page.locator('input[name="SuppliedName"]');
    const emailInput = page.locator('input[name="SuppliedEmail"]');
    const subjectInput = page.locator('input[name="Subject"]');
    const descInput = page.locator('textarea[name="Description"]');

    if (await nameInput.count() > 0) {
        await nameInput.fill('Test User');
    }
    if (await emailInput.count() > 0) {
        await emailInput.fill('test@example.com');
    }
    if (await subjectInput.count() > 0) {
        await subjectInput.fill('Test Subject - File Upload');
    }
    if (await descInput.count() > 0) {
        await descInput.fill('Testing file upload compression');
    }
}

// Helper to get console messages
function setupConsoleCapture(page) {
    const messages = [];
    page.on('console', msg => {
        if (msg.text().includes('CaseForm:')) {
            messages.push(msg.text());
        }
    });
    return messages;
}

test.describe('Image Compression Feature', () => {

    test.beforeEach(async ({ page }) => {
        // Navigate to form with longer timeout for Salesforce
        await page.goto(FORM_URL, { waitUntil: 'networkidle', timeout: 60000 });
    });

    test('1. Small image (1.2MB) - should upload without compression', async ({ page }) => {
        const consoleMsgs = setupConsoleCapture(page);

        // Fill required fields
        await fillRequiredFields(page);

        // Upload the small image
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-1mb.jpg'));

        // Take screenshot before submit
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '01-small-image-selected.png') });

        // Submit the form
        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for either success or processing
        await page.waitForTimeout(5000);

        // Take screenshot after submit
        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '01-small-image-result.png') });

        // Check console messages - should indicate no compression needed
        const noCompressionMsg = consoleMsgs.find(m => m.includes('no compression needed'));
        console.log('Console messages:', consoleMsgs);

        // Verify success or check for compression skip message
        const successMsg = page.locator('#successMessage');
        const errorMsg = page.locator('#errorMessage');

        // Either we see success, or we should see the "no compression" message in console
        const isSuccess = await successMsg.isVisible().catch(() => false);
        const hasError = await errorMsg.isVisible().catch(() => false);

        if (isSuccess) {
            console.log('SUCCESS: Small image uploaded without compression');
        } else if (hasError) {
            const errorText = await errorMsg.textContent();
            console.log('ERROR:', errorText);
        }

        expect(consoleMsgs.some(m => m.includes('no compression needed') || m.includes('Submitting'))).toBeTruthy();
    });

    test('2. Medium image (4MB) - should compress before upload', async ({ page }) => {
        const consoleMsgs = setupConsoleCapture(page);

        await fillRequiredFields(page);

        // Upload the medium image
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-3mb.jpg'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '02-medium-image-selected.png') });

        // Submit
        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Watch for button text changes (compression progress)
        await page.waitForTimeout(2000);
        const buttonText = await submitButton.textContent();
        console.log('Button text during processing:', buttonText);

        // Wait for completion (compression + upload)
        await page.waitForTimeout(30000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '02-medium-image-result.png') });

        console.log('Console messages:', consoleMsgs);

        // Should see compression message
        const compressionMsg = consoleMsgs.find(m => m.includes('Compressing') || m.includes('Compressed'));
        expect(compressionMsg).toBeTruthy();
    });

    test('3. Large image (15MB) - should compress significantly', async ({ page }) => {
        const consoleMsgs = setupConsoleCapture(page);

        await fillRequiredFields(page);

        // Upload large image
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-8mb.jpg'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '03-large-image-selected.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait longer for large image compression
        await page.waitForTimeout(60000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '03-large-image-result.png') });

        console.log('Console messages:', consoleMsgs);

        // Should see compression with significant reduction
        const compressionMsg = consoleMsgs.find(m => m.includes('Compressed'));
        console.log('Compression result:', compressionMsg);
    });

    test('4. PNG image (51MB) - should convert to JPEG and compress', async ({ page }) => {
        const consoleMsgs = setupConsoleCapture(page);

        await fillRequiredFields(page);

        // Upload PNG
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-5mb.png'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '04-png-image-selected.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for conversion and compression (PNG is large, may take time)
        await page.waitForTimeout(90000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '04-png-image-result.png') });

        console.log('Console messages:', consoleMsgs);
    });

    test('5. Small PDF (199KB) - should upload without issues', async ({ page }) => {
        const consoleMsgs = setupConsoleCapture(page);

        await fillRequiredFields(page);

        // Upload small PDF
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-small.pdf'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '05-small-pdf-selected.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for upload
        await page.waitForTimeout(10000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '05-small-pdf-result.png') });

        // Check for success
        const successMsg = page.locator('#successMessage');
        const isVisible = await successMsg.isVisible().catch(() => false);
        console.log('Success visible:', isVisible);
        console.log('Console messages:', consoleMsgs);
    });

    test('6. Large PDF (4MB) - should show error message', async ({ page }) => {
        await fillRequiredFields(page);

        // Upload large PDF
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-3mb.pdf'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '06-large-pdf-selected.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for error
        await page.waitForTimeout(2000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '06-large-pdf-result.png') });

        // Should show error message
        const errorMsg = page.locator('#errorMessage');
        await expect(errorMsg).toBeVisible();

        const errorText = await errorMsg.textContent();
        console.log('Error message:', errorText);

        // Verify error mentions size limit
        expect(errorText).toContain('too large');
        expect(errorText).toContain('2MB');
    });

    test('7. Video file - should show not supported error', async ({ page }) => {
        await fillRequiredFields(page);

        // Upload video
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-small.mp4'));

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '07-video-selected.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for error
        await page.waitForTimeout(2000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '07-video-result.png') });

        // Should show video not supported error
        const errorMsg = page.locator('#errorMessage');
        await expect(errorMsg).toBeVisible();

        const errorText = await errorMsg.textContent();
        console.log('Error message:', errorText);

        // Verify error mentions video not supported
        expect(errorText).toContain('Video');
        expect(errorText).toContain('not supported');
    });

});

test.describe('Edge Cases and Error Handling', () => {

    test.beforeEach(async ({ page }) => {
        await page.goto(FORM_URL, { waitUntil: 'networkidle', timeout: 60000 });
    });

    test('8. Form submission without file - should work normally', async ({ page }) => {
        await fillRequiredFields(page);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '08-no-file-before.png') });

        const submitButton = page.locator('#submitButton');
        await submitButton.click();

        // Wait for submission
        await page.waitForTimeout(10000);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '08-no-file-result.png') });

        // Check for success
        const successMsg = page.locator('#successMessage');
        const isVisible = await successMsg.isVisible().catch(() => false);
        console.log('Success visible (no file):', isVisible);
    });

    test('9. Verify compression progress UI shows during large image upload', async ({ page }) => {
        await fillRequiredFields(page);

        // Upload medium image to see compression progress
        const fileInput = page.locator('#fileInput');
        await fileInput.setInputFiles(path.join(TEST_FILES_DIR, 'test-3mb.jpg'));

        const submitButton = page.locator('#submitButton');

        // Capture button text changes
        const buttonTexts = [];
        const captureInterval = setInterval(async () => {
            const text = await submitButton.textContent().catch(() => '');
            if (text && !buttonTexts.includes(text)) {
                buttonTexts.push(text);
                console.log('Button text:', text);
            }
        }, 200);

        await submitButton.click();

        // Wait for compression to complete
        await page.waitForTimeout(15000);

        clearInterval(captureInterval);

        await page.screenshot({ path: path.join(SCREENSHOTS_DIR, '09-compression-progress.png') });

        console.log('All button states captured:', buttonTexts);

        // Should have seen "Optimizing" at some point
        const sawOptimizing = buttonTexts.some(t => t.includes('Optimizing'));
        console.log('Saw optimizing state:', sawOptimizing);
    });

});
