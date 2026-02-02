// @ts-check
const { test, expect } = require('@playwright/test');

const getFrontdoorUrl = async () => {
    const { execSync } = require('child_process');
    const output = execSync('sf org open --target-org devorg --url-only 2>&1', { encoding: 'utf-8' });
    const match = output.match(/https:\/\/[^\s]+frontdoor\.jsp[^\s]+/);
    if (!match) throw new Error('Could not get frontdoor URL');
    return match[0];
};

test('Site Dropdown UX - Complete verification', async ({ page }) => {
    const frontdoorUrl = await getFrontdoorUrl();
    const urlMatch = frontdoorUrl.match(/(https:\/\/[^\/]+)/);
    const baseUrl = urlMatch ? urlMatch[1] : '';

    // Step 1: Login and navigate to Form Manager
    console.log('Step 1: Logging in and navigating to Form Manager...');
    const frontdoorWithRedirect = frontdoorUrl.split('?')[0] + '?' +
        frontdoorUrl.split('?')[1].split('&')[0] +
        '&retURL=' + encodeURIComponent('/lightning/n/Form_Manager');

    await page.goto(frontdoorWithRedirect, { waitUntil: 'load', timeout: 60000 });
    await page.waitForTimeout(5000);

    if (!page.url().includes('Form_Manager')) {
        await page.goto(baseUrl + '/lightning/n/Form_Manager', { waitUntil: 'load', timeout: 60000 });
        await page.waitForTimeout(5000);
    }

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-01-list.png', fullPage: true });

    // ==========================================
    // TEST PART A: Edit existing form
    // ==========================================
    console.log('\n--- TEST A: Edit Existing Form ---');

    // Step 2: Edit an existing form via row actions
    console.log('Step 2: Opening existing form for editing...');
    const rowActionDropdown = page.locator('tbody tr').first().locator('button[slot="trigger"], lightning-button-menu button').last();

    if (await rowActionDropdown.isVisible({ timeout: 5000 }).catch(() => false)) {
        await rowActionDropdown.click();
        await page.waitForTimeout(1000);

        const editMenuItem = page.locator('lightning-menu-item').filter({ hasText: /^Edit$/ });
        if (await editMenuItem.isVisible({ timeout: 3000 }).catch(() => false)) {
            await editMenuItem.click();
            await page.waitForTimeout(3000);
        }
    }

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-02-edit-form.png', fullPage: true });

    // Step 3: Find the Site dropdown and verify its state
    console.log('Step 3: Testing Site dropdown...');

    // Find the Site combobox
    const siteCombobox = page.locator('lightning-combobox').filter({ hasText: 'Site' });
    await expect(siteCombobox).toBeVisible({ timeout: 10000 });

    // Get the selected value from the combobox button
    const dropdownButton = siteCombobox.locator('button[role="combobox"]');
    const selectedValue = await dropdownButton.getAttribute('data-value');
    console.log(`Currently selected value: "${selectedValue}"`);

    // TEST A1: Verify a site is selected (not empty)
    expect(selectedValue).toBeTruthy();
    console.log('✓ A site is pre-selected');

    // TEST A2: Verify the selected value contains "(Default)" marker
    expect(selectedValue).toContain('(Default)');
    console.log('✓ Selected site has "(Default)" marker');

    // Step 4: Open the dropdown to check options
    console.log('Step 4: Opening dropdown to verify options...');
    await dropdownButton.click();
    await page.waitForTimeout(1000);

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-03-dropdown-open.png', fullPage: true });

    // Get the dropdown listbox content
    const listbox = page.locator('div[role="listbox"]');
    await expect(listbox).toBeVisible({ timeout: 5000 });

    const listboxText = await listbox.textContent();
    console.log(`Dropdown content: "${listboxText}"`);

    // TEST A3: Verify "Use Default Site" is NOT present
    expect(listboxText).not.toContain('Use Default Site');
    console.log('✓ "Use Default Site" option is removed');

    // TEST A4: Verify "(Default)" marker is present in dropdown
    expect(listboxText).toContain('(Default)');
    console.log('✓ "(Default)" marker present in dropdown options');

    // Close dropdown
    await page.keyboard.press('Escape');
    await page.waitForTimeout(500);

    // Step 5: Verify the Public URL is displayed
    console.log('Step 5: Verifying Public URL...');
    const publicUrlLabel = page.locator('label:has-text("Public URL")');
    const hasPublicUrlLabel = await publicUrlLabel.isVisible({ timeout: 5000 }).catch(() => false);
    console.log(`Public URL label visible: ${hasPublicUrlLabel}`);
    expect(hasPublicUrlLabel).toBe(true);
    console.log('✓ Public URL section is displayed');

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-04-edit-complete.png', fullPage: true });

    // ==========================================
    // TEST PART B: New form
    // ==========================================
    console.log('\n--- TEST B: New Form ---');

    // Go back to list and create new form
    console.log('Step 6: Going back to list view...');
    await page.locator('button:has-text("Cancel")').click();
    await page.waitForTimeout(2000);

    // Click New Form
    console.log('Step 7: Clicking New Form button...');
    const newFormButton = page.locator('button:has-text("New Form")');
    await newFormButton.click();
    await page.waitForTimeout(3000);

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-05-new-form.png', fullPage: true });

    // Find the Site combobox and check value
    const newSiteCombobox = page.locator('lightning-combobox').filter({ hasText: 'Site' });
    await expect(newSiteCombobox).toBeVisible({ timeout: 10000 });

    const newDropdownButton = newSiteCombobox.locator('button[role="combobox"]');
    const newFormSiteValue = await newDropdownButton.getAttribute('data-value');
    console.log(`New form site value: "${newFormSiteValue}"`);

    // TEST B1: New forms should have default site pre-selected
    expect(newFormSiteValue).toBeTruthy();
    console.log('✓ New form has a site pre-selected');

    // TEST B2: The pre-selected site should be the default
    expect(newFormSiteValue).toContain('(Default)');
    console.log('✓ New form has default site pre-selected with "(Default)" marker');

    await page.screenshot({ path: 'tests/screenshots/site-dropdown-06-final.png', fullPage: true });

    console.log('\n========================================');
    console.log('=== ALL SITE DROPDOWN TESTS PASSED ===');
    console.log('========================================');
    console.log('\nSummary:');
    console.log('  ✓ "Use Default Site" option removed');
    console.log('  ✓ Default site marked with "(Default)"');
    console.log('  ✓ Existing forms show default site selected');
    console.log('  ✓ New forms auto-select default site');
    console.log('  ✓ Public URL displays correctly');
});
