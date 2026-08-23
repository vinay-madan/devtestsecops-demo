#!/usr/bin/env node
import { execSync } from 'node:child_process';

const checks = [
  ['node',       'node --version'],
  ['git',        'git --version'],
  ['docker',     'docker info --format "{{.ServerVersion}}"'],
  ['jq',         'jq --version'],
  ['semgrep',    'semgrep --version'],
  ['trufflehog', 'trufflehog --version'],
  ['trivy',      'trivy --version'],
  ['nuclei',     'nuclei -version'],
  ['ollama',     'ollama list'],
  ['playwright', 'npx playwright --version']
];

let failed = 0;
for (const [name, cmd] of checks) {
  try {
    const out = execSync(cmd, { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim().split('\n')[0];
    console.log(`  ok    ${name.padEnd(12)} ${out}`);
  } catch {
    failed++;
    console.log(`  FAIL  ${name.padEnd(12)} not available`);
  }
}

// Ollama API (for local-LLM triage)
try {
  const r = await fetch('http://localhost:11434/api/tags');
  const models = (await r.json()).models?.map(m => m.name).join(', ');
  console.log(`  ok    ollama api   ${models}`);
} catch { failed++; console.log('  FAIL  ollama api   not responding on :11434'); }

// Juice Shop source present for SAST
import { existsSync } from 'node:fs';
if (existsSync('src/juice-shop')) console.log('  ok    juice source src/juice-shop');
else { failed++; console.log('  FAIL  juice source src/juice-shop missing — run ./scripts/setup.sh'); }

console.log(failed ? `\n${failed} check(s) failed.` : '\nAll checks passed. You are ready.');
process.exit(failed ? 1 : 0);
