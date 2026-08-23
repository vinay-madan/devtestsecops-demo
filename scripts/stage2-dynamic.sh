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
nuclei -u "$BASE" -t nuclei/templates/ -severity low,medium,high,critical -j -o out/nuclei.json -silent -stats || true
pause

echo "[2/5]  ZAP — baseline passive scan (deeper, still headless)"
docker run --rm -v "$PWD/out:/zap/wrk:rw" \
  ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t "$BASE" -J zap.json -I || true
echo "       report -> out/zap.json"
pause

echo "[3/5]  Live exploits — the three the room will remember"
./scripts/exploits.sh
pause

echo "[4/5]  Playwright — the same exploits, proven in a real browser"
npx playwright test tests/security.spec.js --reporter=list || true
echo "       report: npx playwright show-report out/playwright"
pause

echo "[5/5]  promptfoo red-teams the support chatbot, then one queue for all of it"
if [ -z "${JUICE_TOKEN:-}" ]; then
  echo "       (tip: export JUICE_TOKEN with the stolen admin token so the chatbot probes authenticate)"
fi
( cd promptfoo && npx promptfoo@latest eval -c promptfooconfig.yaml || true )
node scripts/upload-findings.mjs
echo
echo "DefectDojo at http://localhost:8080 — every scanner, deduplicated, with owners and SLAs."
echo "Stop the app when you're done:  docker stop juice-shop"
