# 001 — substrate — tasks

_Generated from `plan.md` on 2026-05-19. Work top-to-bottom. Check boxes as tasks complete. If a task reveals the plan is wrong, update `plan.md` before continuing._

## Implementation

### Pre-flight — decisions + setup (Day 0)

- [ ] 1. Verify GitHub org `acmeyard` namespace availability; if taken, pick alternative (`acme-yard`, `acmeyard-co`) and record in `notes.md`
- [ ] 2. Decide Satis vs Private Packagist for `packages.acmeyard.com` (provisional: Satis); record decision + reasoning in `notes.md`
- [ ] 3. Decide storefront stack (provisional: Laravel + substrate as product 0; alternatives: Astro static, Next.js); record decision in `notes.md`
- [ ] 4. Lock dependency versions for substrate v1.0: Laravel framework, Filament, Cashier (Stripe), Pulse, Sentry-Laravel, spatie/laravel-multitenancy, owen-it/laravel-auditing, Prism PHP, Pest, Pint, PHPStan, Larastan; document in `notes.md` as the v1.x compatibility baseline

### Week 1 — Substrate primitives: auth + multi-tenant + license-key

- [ ] 5. Create `acmeyard/substrate` GitHub repo (or `cfpperche/acmeyard-substrate` if org not ready); add `composer.json` with locked deps from task 4, `LICENSE.md` (BSL 1.1 mirroring acmeyard root), `README.md` skeleton, `.gitignore`, `.gitattributes`
- [ ] 6. Scaffold `src/SubstrateServiceProvider.php` + publishable `config/substrate.php` with keys: `LICENSE_KEY`, `LICENSE_API_URL` (default `https://acmeyard.com`), `LICENSE_GRACE_DAYS` (default 14), `BILLING_PROVIDER` (default `stripe`), `AI_PROVIDER` (default `openai`), `TENANCY_MODE` (default `row`)
- [ ] 7. Add tooling configs: `phpstan.neon` (level 8 + larastan), `pint.json` (Laravel preset), `pest.config.php`, `.github/workflows/ci.yml` running Pest + Pint --test + PHPStan analyse on PHP 8.3 + 8.4 matrix with `orchestra/testbench` host
- [ ] 8. Implement `Tenant` Eloquent model + factory + migration `create_tenants_table` (id UUID, name, slug, created_at, updated_at)
- [ ] 9. Implement `BelongsToTenant` trait: `booted()` adds global scope filtering by `app('currentTenant')?->id`; `saving` event auto-stamps `tenant_id` on create
- [ ] 10. Implement `ResolveTenant` HTTP middleware + container singleton `currentTenant`; resolves from authenticated user's `tenant_id` (or panel scope)
- [ ] 11. Implement `LicenseClient` HTTP layer (Guzzle/HTTP facade) calling `POST {LICENSE_API_URL}/api/licenses/validate` + filesystem cache at `storage/app/substrate/license-cache.json` (key, status, last_validated_at)
- [ ] 12. Implement `LicenseValidator` boot-time check invoked from SubstrateServiceProvider; reads env, calls client, applies grace period; raises `LicenseInvalidException` / `LicenseExpiredException` if invalid AND past grace
- [ ] 13. Implement `php artisan substrate:license:status` console command displaying key (masked), tier, expiry, last validation, days-since-online
- [ ] 14. Wire `SubstrateBreezeServiceProvider` integrating Laravel Breeze with substrate conventions (admin guard separate from web guard, `EnsureLicenseValid` middleware on protected routes)
- [ ] 15. Pest test: tenancy scope (write as tenant A, read returns only tenant A rows; cross-tenant query returns empty)
- [ ] 16. Pest test: license validator — valid response unlocks; invalid response throws; offline + within grace caches and proceeds; offline + past grace throws
- [ ] 17. Pest test: license cache file written/read correctly with permissions
- [ ] 18. Pest test: ResolveTenant middleware sets `app('currentTenant')` from auth user
- [ ] 19. **Smoke test — risk #4 mitigation**: install Filament 3 in Testbench, create a stub Resource against a `BelongsToTenant` model, assert list query returns tenant-scoped data (no leakage); document any `query()` override pattern required as substrate convention

### Week 2 — Billing + audit + Filament + AI + observability

- [ ] 20. Add `subscriptions` + `plans` migrations + `Subscription` model + factory (tenant_id, plan_id, stripe_id, status, ends_at)
- [ ] 21. Implement `StripeProvider` concrete (Cashier wrapper) with methods: `subscribe(Plan, Customer)`, `cancel(Subscription)`, `invoice(Subscription)`, `webhookHandler(Request)`
- [ ] 22. Extract `BillingProvider` interface from `StripeProvider` shape; bind in service container; document contract in interface PHPDoc
- [ ] 23. Implement `StripeWebhookController` handling `checkout.session.completed`, `customer.subscription.updated`, `customer.subscription.deleted`
- [ ] 24. Pest test: BillingProvider swap — bind fake `TestPagarmeProvider` in test, assert subscribe call routes there without substrate code change
- [ ] 25. Add `audits` migration (wrapping owen-it/laravel-auditing default schema); implement `Auditable` trait wrapping the canonical trait with substrate defaults (audits user, tenant_id, IP, user agent)
- [ ] 26. Pest test: audit log creation — stub Patient model with Auditable trait, modify in Filament context, assert audits row created with all expected fields
- [ ] 27. Implement `SubstratePanelProvider` Filament 3 panel + register 5 Resources: `UserResource`, `TenantResource`, `LicenseResource`, `AuditLogResource`, `SubscriptionResource`
- [ ] 28. Implement `AcmeYardTheme` base theme: Tailwind tokens (Acme Yard palette + typography) + Filament theme.css under `resources/css/filament/admin/theme.css`
- [ ] 29. Pest test: panel auto-discovery — product registers `MeiExpenseResource extends Resource`, asserts it shows in substrate panel without panel re-config
- [ ] 30. Implement `AiClient` facade wrapping Prism PHP: `chat(array $messages)`, `structured(string $jsonSchemaClass, string $prompt): DTO`
- [ ] 31. Implement `JsonSchemaValidator` mapping Prism structured response → typed DTO; raise `InvalidStructuredResponseException` on schema mismatch
- [ ] 32. Pest test: AiClient — stub Prism client, assert chat() and structured() route correctly; integration test against real OpenAI + Anthropic for one structured prompt (skipped in CI unless `INTEGRATION_AI=1`)
- [ ] 33. Implement `SentryConfigurer` service provider with no-op fallback when `SENTRY_LARAVEL_DSN` is empty; require `sentry/sentry-laravel`
- [ ] 34. Add `laravel/pulse` to substrate require; verify `/pulse` route renders in Testbench with substrate-default cards (slow queries, queue depth, cache hit rate)
- [ ] 35. Pest test: Sentry no-op when DSN empty (exception in test does not crash on Sentry init)

### Week 3 — Distribution infrastructure (Satis + storefront + fluxo-mei template)

- [ ] 36. Create GitHub org `acmeyard` (from task 1 decision); transfer or recreate substrate repo under org; lock org members + 2FA
- [ ] 37. Provision VPS or Coolify instance for `packages.acmeyard.com`; add A record (Cloudflare DNS) pointing at instance; verify TLS via Cloudflare proxy or Let's Encrypt
- [ ] 38. Install Satis on the instance; `satis.json` indexing `acmeyard/substrate` + `acmeyard/fluxo-mei`; configure HTTP Basic auth via `.htpasswd` (license tokens as user:token pairs, hashed)
- [ ] 39. Create `acmeyard/fluxo-mei` template repo: `composer.json` (require: `acmeyard/substrate: ^1.0`, `laravel/framework: ^11.0`; scripts.post-create-project-cmd runs `php artisan substrate:install`), `.env.example` with LICENSE_KEY + substrate env stubs
- [ ] 40. Add to `acmeyard/fluxo-mei` template: empty `app/{Models,Http/Controllers,Filament/Resources}/.gitkeep`, `bootstrap/providers.php` registering `SubstratePanelProvider`
- [ ] 41. Add deploy artifacts to `acmeyard/fluxo-mei` template: `Dockerfile` (multi-stage PHP 8.3-fpm + Nginx + supervisor), `docker-compose.yml` (PostgreSQL 17 + Redis 7 + app), `coolify.json` with Coolify-specific deploy hints
- [ ] 42. Add `.github/workflows/ci.yml` to `acmeyard/fluxo-mei` template (Pest + Pint --test + PHPStan analyse + PHP 8.3 + 8.4 matrix)
- [ ] 43. Implement `php artisan substrate:install` console command in substrate: publishes config, runs all substrate migrations, seeds via `dev:seed` if `--seed` flag passed
- [ ] 44. Implement `php artisan dev:seed` console command in substrate: 1 admin User + 3 Tenants + 1 active License + 5 AuditLog entries + 1 Subscription
- [ ] 45. Create `acmeyard/storefront` repo with chosen stack (from task 3); minimal: landing page + Stripe Checkout button + license issuance webhook + Mailgun config
- [ ] 46. Implement storefront `POST /api/licenses/issue`: Stripe webhook on `checkout.session.completed` → generate per-license token (HTTP Basic auth user:token) → persist → email customer via Mailgun with `auth.json` snippet
- [ ] 47. Implement storefront `POST /api/licenses/validate`: substrate's runtime endpoint; returns `{valid, tier, expires_at, tenant_id}` for token; rate-limited
- [ ] 48. Implement storefront `POST /api/licenses/revoke`: admin-only; invalidates a license token (synced to Satis `.htpasswd`)
- [ ] 49. Set up Mailgun account + verify acmeyard.com sender domain; create email template for license issuance (includes auth.json instructions)
- [ ] 50. Add `.github/workflows/release.yml` in substrate repo: on git tag `v*` → trigger Satis re-index via webhook; publish release notes to GitHub Releases

### Week 4 — Dogfood + ship v1.0.0

- [ ] 51. Cold run: from a fresh directory, run `composer create-project acmeyard/fluxo-mei meu-fluxo --repository="https://packages.acmeyard.com"` with a real auth.json token (use Stripe test mode to issue one); verify package downloads, install command runs, dev:seed populates
- [ ] 52. In fresh `meu-fluxo` directory: verify `php artisan test` green (Pest), `vendor/bin/pint --test` green, `vendor/bin/phpstan analyse` green, all on the unmodified scaffold
- [ ] 53. In fresh `meu-fluxo`: verify `docker compose up` boots stack (app + PostgreSQL + Redis); visit `/admin` → Filament panel renders all 5 substrate Resources + AcmeYard theme
- [ ] 54. Build Fluxo MEI v1 feature surface ON TOP of fresh `meu-fluxo` (additive only, zero edits to `vendor/acmeyard/substrate/`): Pix-watcher integration + AI categorization via `AiClient::structured(MeiCategoryDTO::class, ...)` + MEI tax reports
- [ ] 55. If task 54 surfaces a substrate API gap: ship `acmeyard/substrate` v1.1.x (backward-compat) and retry task 54; if breaking change required, escalate plan to v2.0 (do NOT silent-break v1)
- [ ] 56. Tag `acmeyard/substrate` v1.0.0; populate `CHANGELOG.md`; verify Satis re-indexed (`composer require acmeyard/substrate:1.0.0` succeeds from a fresh Composer config with auth.json)
- [ ] 57. Update `cfpperche/acmeyard` (this repo) README.md: add link to `acmeyard/substrate` repo + link to acmeyard.com storefront; commit to `cfpperche/acmeyard`

## Verification

Each verification maps to one acceptance scenario in `spec.md`:

- [ ] **substrate ships local auth + Filament admin auth** — verified by tasks 14 + 27 + manual smoke on `meu-fluxo` after task 53
- [ ] **BillingProvider contract is swappable** — verified by Pest test in task 24
- [ ] **license-key validator gates substrate at boot** — verified by Pest test in task 16 (valid/invalid/offline-within-grace/offline-past-grace)
- [ ] **row-level multi-tenant scopes Eloquent models automatically** — verified by Pest test in task 15
- [ ] **LGPD audit log records PII access automatically** — verified by Pest test in task 26
- [ ] **Sentry DSN is opt-in via .env** — verified by Pest test in task 35 (empty DSN → no crash)
- [ ] **Laravel Pulse renders out-of-the-box** — verified by task 34 (Testbench) + task 53 (`meu-fluxo` /pulse route)
- [ ] **AiClient exposes chat + structured-output** — verified by Pest test in task 32 + integration check
- [ ] **Filament panel extension is one-line** — verified by Pest test in task 29 + task 54 (MeiExpenseResource auto-discovers in fluxo-mei panel)
- [ ] **Stripe checkout issues a working auth.json token** — verified end-to-end in tasks 46 + 49 + 51 (Stripe test mode → email → composer create-project succeeds with the token)
- [ ] **composer create-project lands a working app in one command** — verified by tasks 51 + 52
- [ ] **dev:seed populates substrate primitives with realistic data** — verified by task 44 + manual inspection during task 53
- [ ] **GitHub Actions CI workflow is functional out-of-the-box** — verified by task 42 + push to fresh test repo after task 51
- [ ] **SemVer is strict + 1 major/year max** — verified by task 56 (CHANGELOG.md populated, UPGRADE.md scaffold present, tag = v1.0.0)
- [ ] **dogfood — Fluxo MEI v1 builds on substrate v1 without refactor** — verified by tasks 54 + 55 (additive-only proof)

## Notes

- **Task ordering rationale.** Pre-flight (1-4) front-loads decisions that block downstream work. Week 1 (5-19) builds the 3 hardest primitives where Eloquent global scopes + license-key offline semantics + Filament-tenancy compatibility carry highest unknowns. Week 2 (20-35) is integration glue — lower risk per task, more parallel-friendly. Week 3 (36-50) is first-time-builder infra (Satis, Stripe webhook, storefront) — isolated to one week so a slip doesn't cascade. Week 4 (51-57) is empirical ratification.
- **Slip handling.** If Week 1 stretches past 7 days, replan toward "minimum viable substrate" (drop Prism AI primitive to v1.1, drop Pulse, ship without storefront-as-product-0) rather than slip beyond Month 0. Substrate v1.0.0 must ship for the 12-microsaas/year cadence to remain credible.
- **Storefront escape hatch.** If task 33 / 45 (storefront stack scaffold) surfaces a 2-week project rather than 2-day, defer storefront entirely to spec 002 and ship substrate v1.0.0 with a manual license-issuance flow (Stripe webhook → manual email from acmeyard.com admin) for Month 1 launch. Substrate doesn't actually require automated storefront in v1.
- **Risk #4 (Filament + multi-tenant) checked early.** Task 19 smoke test happens Week 1 Day 5; if Filament needs explicit `query()` overrides on Resources, that's a substrate convention to document in `README.md` + add as a tasks.md follow-up.
- **AI integration test gating.** Task 32's real-OpenAI + real-Anthropic test is opt-in via `INTEGRATION_AI=1`; CI runs the stubbed version only. Avoids burning API budget on every PR.
- **`notes.md` is append-only during execution.** Decisions made under ambiguity (e.g. exact BillingProvider method signatures, License grace period semantics under odd network conditions, Satis auth middleware details) → `notes.md` § Design decisions. Plan deviations → `notes.md` § Deviations. See `.claude/rules/spec-driven.md` § The four artifacts.
- **Pre-existing dirty files** in this repo (`.claude/skills/brainstorm/templates/render.html.tmpl` etc. in Agent0) are NOT this spec's concern; sibling sessions own them.
- **Storefront stack decision (task 3)** affects task 45+ implementation but NOT the substrate package itself. Substrate v1 can be released to Satis before the storefront is finished; first paying customer just needs a working `/api/licenses/issue` endpoint at the time of purchase.
