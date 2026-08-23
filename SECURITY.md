# Security policy

## This repository is intentionally vulnerable

`devtestsecops-demo` is teaching material for a conference talk on shift-left security testing. The
application in `app/` was written to fail scanners and tests on purpose. The vulnerabilities are the
content, not a mistake.

**Please do not report them.** Findings from Semgrep, Trivy, Nuclei, TruffleHog, GitHub code scanning,
Dependabot or any other tool pointed at this repository are expected and will not be fixed.

Known-intentional issues include SQL injection, reflected XSS, a hard-coded synthetic credential, missing
security headers, insecure cookie flags, an exposed `/debug/config` route, a prompt-injectable chat
endpoint, and an outdated container base image carrying known CVEs.

## Credentials

There are no real secrets here. `sk-support-DEMO-NOT-A-REAL-KEY-0000` is a placeholder chosen to be
obviously synthetic while still matching the secret-scanning patterns the demo relies on. The seeded user
accounts (`alice`, `bob`) exist only in an in-memory SQLite database.

## Safe use

Run it on localhost, in a container, with no network exposure and no real data. Stop it when you are done.
Do not deploy it anywhere, including a private staging environment.

## Something genuinely wrong?

If you have found a problem that is *not* one of the deliberate flaws — for example something harmful in the
tooling scripts, or a real credential committed by accident — please open an issue without exploit detail and
it will be dealt with promptly.
