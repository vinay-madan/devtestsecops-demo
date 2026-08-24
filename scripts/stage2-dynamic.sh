#!/usr/bin/env bash
# STAGE 2 — DYNAMIC: prove it against the running app.
# Nuclei (fast DAST) -> ZAP (deeper baseline) -> live exploits -> Playwright proof -> promptfoo chatbot -> DefectDojo.
# Run from the demo/ root:  ./scripts/stage2-dynamic.sh
set -euo pipefail
mkdir -p out
pause() { echo; read -rp "  [enter to continue] "; clear; }

BASE=${BASE_URL:-http://localhost:3000}
IMAGE=${JUICE_IMAGE:-bkimminich/juice-shop:latest}

clear
echo "STAGE 2 — DYNAMIC  ·  prove it against the running app"
echo "Starting Juice Shop at $BASE ..."
docker rm -f juice-shop >/dev/null 2>&1 || true
docker run --rm -d --name juice-shop -p 3000:3000 "$IMAGE" >/dev/null
printf "   waiting for boot"
until curl -sf "$BASE/rest/admin/application-version" >/dev/null 2>&1; do printf "."; sleep 1; done
echo " up."
pause

echo "[1/5]  Nuclei — fast DAST that fits a pull-request budget"
nuclei -u "$BASE" -t nuclei-templates/ -severity low,medium,high,critical -j -o out/nuclei.json -silent -stats || true
pause

echo "[2/5]  ZAP — baseline passive scan (deeper, still headless)"
# ZAP runs in its own container, so localhost points at that container, not the host.
# Reach the host-published Juice Shop via host.docker.internal (add-host makes it work on Linux too).
ZAP_TARGET=${ZAP_TARGET:-http://host.docker.internal:3000}
docker run --rm --add-host=host.docker.internal:host-gateway -v "$PWD/out:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t "$ZAP_TARGET" -J zap.json -x zap.xml -I || true
echo "       report -> out/zap.json (human) + out/zap.xml (DefectDojo)"
pause

echo "[3/5]  Live exploits"
# Steal the admin JWT once (SQLi) and export it so the chatbot probes authenticate.
JUICE_TOKEN=$(curl -s "$BASE/rest/user/login" \
  -H 'Content-Type: application/json' \
  -d '{"email":"'"'"' OR 1=1--","password":"x"}' | jq -r '.authentication.token // empty')
export JUICE_TOKEN
./scripts/exploits.sh
pause

echo "[4/5]  Playwright — the same exploits, proven in a real browser"
npx playwright test tests/security.spec.js --reporter=list || true
echo "       report: npx playwright show-report out/playwright"
pause

echo "[5/5]  promptfoo red-teams the local support assistant, then one queue for all of it"
echo "       (targets Ollama on :11434 — this Juice Shop image ships no chatbot route)"
( cd promptfoo && npx promptfoo@latest eval -c promptfooconfig.yaml -o ../out/promptfoo.json || true )
node scripts/upload-findings.mjs
echo
echo "DefectDojo at http://localhost:8080 — every scanner, deduplicated, with owners and SLAs."
echo "Stop the app when you're done:  docker stop juice-shop"
