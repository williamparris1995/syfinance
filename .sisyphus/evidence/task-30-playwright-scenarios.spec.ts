import { test, expect } from '@playwright/test';
import path from 'path';

test.describe('Task 30: Currency Settings Page QA', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to settings page
    await page.goto('http://localhost:5173/settings');
    await page.waitForLoadState('networkidle');
  });

  test('Scenario 1: Add currency USD with exchange rate', async ({ page }) => {
    // Click "Add Currency" button
    await page.getByRole('button', { name: /Add Currency/i }).click();

    // Wait for dialog to open
    await expect(page.getByRole('dialog')).toBeVisible();
    await expect(page.getByText('Add a new currency')).toBeVisible();

    // Fill form
    await page.getByLabel(/Currency Code/i).fill('USD');
    await page.getByLabel(/Currency Symbol/i).fill('$');
    await page.getByLabel(/Exchange Rate/i).fill('7.25');

    // Click Save
    await page.getByRole('button', { name: /Add Currency/i }).last().click();

    // Wait for dialog to close and currency to appear in list
    await page.waitForTimeout(1000);

    // Assert USD appears in currency list
    await expect(page.getByText('USD')).toBeVisible();
    
    // Assert exchange rate displayed correctly (1 USD = 7.25 CNY)
    const exchangeRateCell = page.locator('text=1 USD = 7.25 CNY');
    await expect(exchangeRateCell).toBeVisible();

    // Take screenshot
    await page.screenshot({ 
      path: path.join('.sisyphus', 'evidence', 'task-30-add-currency.png'),
      fullPage: true 
    });
  });

  test('Scenario 2: Invalid currency code rejected', async ({ page }) => {
    // Click "Add Currency" button
    await page.getByRole('button', { name: /Add Currency/i }).click();

    // Wait for dialog
    await expect(page.getByRole('dialog')).toBeVisible();

    // Test 1: Only 2 letters (invalid)
    await page.getByLabel(/Currency Code/i).fill('US');
    await page.getByLabel(/Currency Symbol/i).fill('$');
    await page.getByLabel(/Exchange Rate/i).fill('7.25');
    await page.getByRole('button', { name: /Add Currency/i }).last().click();

    // Assert validation error appears
    await expect(page.getByText(/Currency code must be exactly 3 characters/i)).toBeVisible();

    // Clear and test 2: Numbers (invalid)
    await page.getByLabel(/Currency Code/i).clear();
    await page.getByLabel(/Currency Code/i).fill('123');
    await page.getByRole('button', { name: /Add Currency/i }).last().click();

    // Assert validation error
    await expect(page.getByText(/Currency code must be 3 uppercase letters/i)).toBeVisible();

    // Take screenshot
    await page.screenshot({ 
      path: path.join('.sisyphus', 'evidence', 'task-30-currency-validation.png'),
      fullPage: true 
    });
  });
});
