#!/usr/bin/env node
// Push every scanner's native report into DefectDojo so the room sees ONE queue.
// Requires: DefectDojo running (docker compose -f defectdojo/docker-compose.yml up -d)
// Auth: uses DD_TOKEN if set; otherwise fetches one from admin creds automatically
//       (DD_ADMIN_USER / DD_ADMIN_PASSWORD, defaulting to the compose values).
import { readFileSync, existsSync } from 'node:fs';

const DD_URL = process.env.DD_URL ?? 'http://localhost:8080';
const DD_USER = process.env.DD_ADMIN_USER ?? 'admin';
const DD_PASS = process.env.DD_ADMIN_PASSWORD ?? 'admin1234!';
const ENGAGEMENT = process.env.DD_ENGAGEMENT ?? '1';

// Use an explicit token if provided, else trade admin creds for one via the API.
async function getToken() {
  if (process.env.DD_TOKEN) return process.env.DD_TOKEN;
  const res = await fetch(`${DD_URL}/api/v2/api-token-auth/`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: DD_USER, password: DD_PASS })
  });
  if (!res.ok) {
    console.error(`Could not fetch API token: ${res.status} ${await res.text()}`);
    console.error('Is DefectDojo up and initialised? Set DD_TOKEN to override.');
    process.exit(1);
  }
  return (await res.json()).token;
}

const TOKEN = await getToken();

// DefectDojo parser names must match exactly (Settings -> supported scan types).
const uploads = [
  { file: 'out/semgrep.sarif',  scanner: 'Semgrep JSON Report' },
  { file: 'out/trufflehog.json', scanner: 'Trufflehog Scan' },
  { file: 'out/trivy.json',     scanner: 'Trivy Scan' },
  { file: 'out/nuclei.json',    scanner: 'Nuclei Scan' },
  { file: 'out/zap.xml',        scanner: 'ZAP Scan' },
  { file: 'out/promptfoo.json', scanner: 'Generic Findings Import' }
];

for (const { file, scanner } of uploads) {
  if (!existsSync(file)) { console.log(`  skip  ${file} (not generated yet)`); continue; }
  const form = new FormData();
  form.append('engagement', ENGAGEMENT);
  form.append('scan_type', scanner);
  form.append('active', 'true');
  form.append('verified', 'false');
  form.append('file', new Blob([readFileSync(file)]), file.split('/').pop());

  const res = await fetch(`${DD_URL}/api/v2/import-scan/`, {
    method: 'POST', headers: { Authorization: `Token ${TOKEN}` }, body: form
  });
  console.log(res.ok ? `  ok    ${scanner}` : `  FAIL  ${scanner}: ${res.status} ${await res.text()}`);
}

console.log(`\nOpen ${DD_URL} — deduplicated across every scanner, with owners and SLAs.`);
