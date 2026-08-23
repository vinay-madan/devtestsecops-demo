#!/usr/bin/env node
// Triage Semgrep SARIF findings with a model running locally via Ollama.
// Usage: node scripts/ai-triage.mjs out/semgrep.sarif
import { readFileSync } from 'node:fs';

const MODEL = process.env.DEMO_MODEL ?? 'qwen2.5-coder:7b';
const sarifPath = process.argv[2] ?? 'out/semgrep.sarif';
const sarif = JSON.parse(readFileSync(sarifPath, 'utf8'));
const results = sarif.runs?.[0]?.results ?? [];

if (!results.length) { console.log('No findings.'); process.exit(0); }
console.log(`\n${results.length} finding(s). Triaging locally with ${MODEL}...\n`);

const context = (file, line, span = 7) => {
  try {
    const lines = readFileSync(file, 'utf8').split('\n');
    return lines.slice(Math.max(0, line - span), line + span).join('\n');
  } catch { return ''; }
};

const PROMPT = `You are an application security reviewer. For the finding below, answer in exactly this format:

VERDICT: exploitable | needs-context | false-positive
WHY: one sentence
FIX: one sentence, concrete
GATE: block | warn | ignore

Keep it under 60 words total. No preamble.`;

for (const [i, r] of results.entries()) {
  const loc = r.locations?.[0]?.physicalLocation;
  const file = loc?.artifactLocation?.uri ?? 'unknown';
  const line = loc?.region?.startLine ?? 0;
  const body = `Rule: ${r.ruleId}\nMessage: ${r.message?.text}\nFile: ${file}:${line}\n\nCode:\n${context(file, line)}`;

  const res = await fetch('http://localhost:11434/api/chat', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      model: MODEL, stream: false, options: { temperature: 0.1 },
      messages: [{ role: 'system', content: PROMPT }, { role: 'user', content: body }]
    })
  });
  const data = await res.json();
  console.log(`─── [${i + 1}/${results.length}] ${r.ruleId}  ${file}:${line}`);
  console.log((data?.message?.content ?? '(no response)').trim(), '\n');
}

console.log('Triage complete. Findings marked GATE: block fail the pipeline.\n');
