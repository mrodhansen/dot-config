# Shipyard workflows reference

Source of truth: https://github.com/Future-Mortgage/shipyard/actions

## Active workflows (typical)

| Workflow | Path | Role for this skill |
|----------|------|---------------------|
| Deploy Dev (GCP) | `.github/workflows/deploy-dev-gcp.yml` | **Primary** — runs integration + e2e after deploy |
| Deploy Prod (GCP) | `.github/workflows/deploy-prod-gcp.yml` | Prod deploy; not the default test target |
| Deploy Infrastructure (GCP) | `.github/workflows/deploy-infra-gcp.yml` | Infra only |
| Deploy Ephemeral Preview (GCP) | `.github/workflows/deploy-ephemeral-gcp.yml` | Preview deploys |

## Deploy Dev job chain

1. `prepare` — tag + monorepo/verification refs, actor/Slack mapping  
2. `build_images` — build container images from monorepo ref  
3. `deploy` — deploy to dev GCP  
4. `integration_tests` — Vitest API/integration suite  
5. `e2e_tests` — Playwright server-crm + web-crm suites  

## Commands executed in shipyard (monorepo checkout)

```bash
# integration_tests
yarn vitest run --config apps/server-crm-e2e/vitest.config.ts --no-file-parallelism

# e2e_tests
npx playwright test --config=apps/server-crm-e2e/playwright.config.ts
npx playwright test --config=apps/web-crm-e2e/playwright.config.ts
```

Env: `TEST_BASE_URL` from shipyard vars (dev host).

## Artifacts

- Name: `e2e-test-results`
- Paths: `apps/server-crm-e2e/test-results/`, `apps/web-crm-e2e/test-results/`

## Useful gh commands

```bash
gh run list --repo Future-Mortgage/shipyard --workflow "Deploy Dev (GCP)" --status failure --limit 10
gh run view <id> --repo Future-Mortgage/shipyard --json jobs
gh run view <id> --repo Future-Mortgage/shipyard --log-failed
gh run download <id> --repo Future-Mortgage/shipyard --name e2e-test-results --dir /tmp/shipyard-e2e-<id>
```

## Fix ownership

| Failure shape | Likely repo |
|---------------|-------------|
| Test assertion / selector / playwright setup | monorepo (`apps/*-e2e` or product UI) |
| API contract / server behavior | monorepo (`apps/server-crm`, shared libs) |
| Wrong image tag, secrets, workflow step, URL var | shipyard |
