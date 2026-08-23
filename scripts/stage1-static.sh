#!/usr/bin/env bash
# STAGE 1 — STATIC: catch it before anything runs (shift-left).
# Semgrep (SAST) -> TruffleHog (secrets) -> Trivy (deps + image CVEs + SBOM) -> local-LLM triage -> gate.
# Run from the demo/ root:  ./scripts/stage1-static.sh
set -euo pipefail
mkdir -p out
pause() { echo; read -rp "  [enter to continue] "; clear; }

SRC=${JUICE_SRC:-src/juice-shop}
IMAGE=${JUICE_IMAGE:-bkimminich/juice-shop:latest}

if [ ! -d "$SRC" ]; then
  echo "Source not found at $SRC — run ./scripts/setup.sh first." >&2; exit 1
fi

clear
echo "STAGE 1 — STATIC  ·  catch it before it ships"
echo "Target: OWASP Juice Shop"
echo "  source: $SRC     image: $IMAGE"
pause

echo "[1/4]  Semgrep — SAST over the source"
echo "       community JS/TS rules + our custom SQLi + secret rules"
semgrep --config p/javascript --config p/typescript --config semgrep/rules.yml \
  --sarif -o out/semgrep.sarif "$SRC/routes" "$SRC/lib" "$SRC/models" 2>/dev/null || true
echo "       findings: $(jq '.runs[0].results | length' out/semgrep.sarif)"
pause

echo "[2/4]  TruffleHog — secret scan over the source tree"
trufflehog filesystem "$SRC" --json --no-update > out/trufflehog.json 2>/dev/null || true
echo "       candidate secrets: $(grep -c . out/trufflehog.json 2>/dev/null || echo 0)"
echo "       (Juice Shop ships hard-coded JWT key material in lib/insecurity.ts)"
pause

echo "[3/4]  Trivy — dependency + base-image CVEs, and the SBOM"
trivy image --scanners vuln --severity HIGH,CRITICAL --format json -o out/trivy.json "$IMAGE"
trivy image --format cyclonedx -o out/sbom.json "$IMAGE"
echo "       HIGH/CRITICAL: $(jq '[.Results[].Vulnerabilities // []] | add | length' out/trivy.json)"
echo "       SBOM -> out/sbom.json   (your Cyber Resilience Act evidence)"
pause

echo "[4/4]  Local-LLM triage"
node scripts/ai-triage.mjs out/semgrep.sarif
echo
echo "Gate: any finding marked GATE: block fails the build. That's shift-left —"
echo "the injection and the CVEs never reach an environment where they can be exploited."
