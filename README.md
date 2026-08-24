# devtestsecops-demo — OWASP Juice Shop edition

> ## ⚠️  THIS TARGETS A DELIBERATELY VULNERABLE APPLICATION
>
> The subject under test is **OWASP Juice Shop** — the most widely used insecure web app for
> security training. It is *designed* to be broken: SQL injection, XSS, broken auth, secret
> exposure, vulnerable dependencies and a prompt-injectable support chatbot are all intentional.
>
> **Run it on localhost only. Do not expose it to a network, and stop the container when you're done.**
> Every finding your scanners report is a real, documented Juice Shop vulnerability — that is the point.

Companion repo for **DevTestSecOps — Secure Shift-Left Testing** (Test Automation & Digital QA Summit, Melbourne).

---

## Why Juice Shop

Juice Shop is a real, full-stack application (Angular SPA + Node/Express REST
API) with famous, genuinely exploitable flaws. Every detection in the pipeline now lands on something the room has
probably read about:

| Flaw | Where | How we detect it |
|---|---|---|
| **SQLi auth bypass** — `' OR 1=1--` logs you in as admin | `POST /rest/user/login` | Semgrep (source) → Nuclei (live) → Playwright (proof) |
| **Reflected / DOM XSS** in product search | `/rest/products/search?q=` and `/#/search` | ZAP → live curl → Playwright browser proof |
| **Chatbot prompt injection** leaks a secret coupon | `POST /rest/chatbot/respond` | promptfoo red-team |
| **Hard-coded key material** | `lib/insecurity.ts` | Semgrep + TruffleHog |
| **Vulnerable dependencies / base image** | container image | Trivy (real CVEs) + SBOM |
| **Exposed `/ftp` directory, missing headers** | server config | Nuclei templates |

---

## 0. What's in here

```
scripts/setup.sh            One-time setup: pull image, clone source, warm caches
scripts/stage1-static.sh    STAGE 1 (static) runner
scripts/stage2-dynamic.sh   STAGE 2 (dynamic) runner
scripts/exploits.sh         The three exploits (mirrors the Hoppscotch collection)
scripts/ai-triage.mjs       Local LLM (Ollama) triage of Semgrep SARIF -> ranked, explained findings
scripts/upload-findings.mjs Push every scanner's report into DefectDojo
scripts/verify.mjs          30-second pre-flight smoke test
semgrep/rules.yml           Custom SQLi + secret + JWT rules (on top of p/javascript, p/typescript)
nuclei/templates/           SQLi login, exposed /ftp, missing-headers templates
promptfoo/                  Prompt-injection red-team suite for the support chatbot
tests/security.spec.js      Playwright exploit proofs (green = exploit confirmed)
hoppscotch/                 Importable Hoppscotch collection for the three exploits
defectdojo/                 docker-compose for the DefectDojo queue
.github/workflows/          The full gated pipeline (runs locally via act)
src/juice-shop/             Shallow clone of the source (created by setup.sh; git-ignored)
```

---

## 1. One-time setup 

```bash
brew install node git docker colima jq semgrep trufflehog trivy nuclei ollama act
colima start --cpu 4 --memory 8        # or open Docker Desktop
cd demo
chmod +x scripts/*.sh
./scripts/setup.sh                     # pulls image, clones source, warms caches, pulls the model
npm run verify                         # everything green before you present
```

---

## 2. The two stages

### STAGE 1 — STATIC · catch it before it ships

```bash
npm run stage1        # or: ./scripts/stage1-static.sh
```

1. **Semgrep** — SAST over `src/juice-shop` (`routes`, `lib`, `models`) with community JS/TS packs plus our custom
   rules. Finds the raw-SQL login query and the hard-coded key.
2. **TruffleHog** — secret scan of the source tree; corroborates the hard-coded JWT key material.
3. **Trivy** — HIGH/CRITICAL CVEs in the image's dependencies, plus a **CycloneDX SBOM** (`out/sbom.json`) — your
   Cyber Resilience Act evidence.
4. **Local-LLM triage** — `ai-triage.mjs` sends only finding metadata + 15 lines of context to a model running on
   your laptop and returns exploitability / fix / gate. **Nothing leaves the machine** — the point for a room that
   can't send source to a hosted model.

The gate: any finding marked `GATE: block` fails the build.

### STAGE 2 — DYNAMIC · prove it against the running app

```bash
npm run stage2        # starts Juice Shop in Docker, then runs everything below
```

1. **Nuclei** — fast, template-driven DAST that fits a pull-request budget (SQLi login, exposed `/ftp`, missing
   headers).
2. **ZAP** — a deeper baseline passive scan, still headless (`out/zap.json`).
3. **Live exploits** (`scripts/exploits.sh`) — the three hero moments (below).
4. **Playwright** — the same exploits proven in a real browser (`npx playwright show-report out/playwright`).
5. **promptfoo** — red-teams the local LLM (Ollama) for the leaked promo code; then `upload-findings.mjs` pushes every
   report into **DefectDojo** as one deduplicated queue with owners and SLAs.

---

## 3. The three exploits — terminal AND Hoppscotch

Start Juice Shop first (stage 2 does this for you, or run it directly):

```bash
docker run --rm -d --name juice-shop -p 3000:3000 bkimminich/juice-shop
```

### Terminal

```bash
BASE_URL=http://localhost:3000 ./scripts/exploits.sh
```

### Hoppscotch

Import `hoppscotch/juice-shop-devtestsecops.json` (Collections → Import → Hoppscotch). Four folders, run top to
bottom:

- **1 · Admin login SQLi** — body `{"email":"' OR 1=1--","password":"anything"}`. The test script saves the stolen
  JWT to the `token` environment variable.
- **2 · Reflected XSS in search** — `q=<iframe src=javascript:alert(1)>`; the response echoes it unencoded. To watch
  it *fire*, open `http://localhost:3000/#/search?q=%3Ciframe%20src%3Djavascript:alert(1)%3E` in a browser.
- **3 · LLM prompt injection** — this Juice Shop image ships no chatbot route, so the probe hits the same local model the pipeline uses (Ollama `:11434`) and tries to pull out the planted promo code `JUICE50`.

> No JWT needed — the target is the local LLM, not Juice Shop. Just have the model running: `ollama run llama3.2:3b`.

---

## 4. Running the whole pipeline locally

```bash
act pull_request -W .github/workflows/secure-pipeline.yml --container-architecture linux/amd64
```
