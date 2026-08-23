#!/usr/bin/env bash
# One-time setup for the Juice Shop DevTestSecOps demo.
# Run from the demo/ root:  ./scripts/setup.sh
set -euo pipefail
mkdir -p out src

IMAGE=${JUICE_IMAGE:-bkimminich/juice-shop:latest}
SRC=${JUICE_SRC:-src/juice-shop}

echo "==> Pulling OWASP Juice Shop image ($IMAGE)"
docker pull "$IMAGE"

echo "==> Shallow-cloning Juice Shop source for SAST (Semgrep + TruffleHog)"
if [ ! -d "$SRC" ]; then
  git clone --depth 1 https://github.com/juice-shop/juice-shop.git "$SRC"
else
  echo "    $SRC already present — skipping"
fi

echo "==> Warming scanner caches (so the stage is fast on stage)"
trivy image --download-db-only
nuclei -update-templates >/dev/null 2>&1 || true
# Prime the Semgrep registry rulepacks used in stage 1
semgrep --config p/javascript --config p/typescript "$SRC/routes" >/dev/null 2>&1 || true

echo "==> Node deps + Playwright browser"
npm install
npx playwright install chromium

echo "==> Local model for triage (~4 GB, comfortable in 16 GB RAM)"
ollama pull qwen2.5-coder:7b
ollama pull llama3.2:3b   # faster fallback

echo
echo "Done. Run 'npm run verify' before you present."
