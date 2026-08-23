#!/usr/bin/env node
// Push every scanner's native report into DefectDojo so the room sees ONE queue.
// Requires: DefectDojo running (docker compose -f defectdojo/docker-compose.yml up -d)
//           DD_TOKEN and DD_ENGAGEMENT set, or edit the defaults below.
import { readFileSync, existsSync } from 'node:fs';

const DD_URL = process.env.DD_URL ?? 'http://localhost:8080';
const TOKEN = process.env.DD_TOKEN ?? 'replace-with-your-api-token';
const ENGAGEMENT = process.env.DD_ENGAGEMENT ?? '1';

// DefectDojo parser names must match exactly (Settings -> supported scan types).
const uploads = [
  { file: 'out/semgrep.sarif',  scanner: 'Semgrep JSON Report' },
  { file: 'out/trufflehog.json', scanner: 'Trufflehog Scan' },
  { file: 'out/trivy.json',     scanner: 'Trivy Scan' },
  { file: 'out/nuclei.json',    scanner: 'Nuclei Scan' },
  { file: 'out/zap.json',       scanner: 'ZAP Scan' },
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
