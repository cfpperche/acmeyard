# 001 — substrate — plan

_Drafted from `spec.md` on 2026-05-19. Update this file if implementation reveals the plan is wrong; do NOT silently diverge._

## Approach

**Package-first, distribution-second, product-validates.** Build `acmeyard/substrate` as a standalone Laravel/Composer package across Weeks 1-2, lift distribution infra (Satis private repo + acmeyard.com storefront + Stripe license-issuance webhook) on top in Week 3, then dogfood by bootstrapping Fluxo MEI v1 via `composer create-project acmeyard/fluxo-mei` in Week 4. The dogfood is the ratification — if Fluxo MEI v1 cannot land additive-only on top of substrate v1.0.0 (zero modifications to `vendor/acmeyard/substrate/`), substrate is not v1-ready and we extend Week 4 instead of declaring done.

The 4-week structure isolates risk per phase: Week 1 = the 3 hardest primitives (multi-tenant interaction with Eloquent globals, license-key offline-grace semantics, auth scaffold). Week 2 = the 2 primitives + 3 transversals that are mostly integration glue (BillingProvider on Cashier, Auditing on Spatie, Filament panel auto-discovery, Sentry, Prism). Week 3 = first-time-builder work (Satis bootstrap, Stripe webhook, storefront landing) — highest unknowns, isolated. Week 4 = empirical validation against a real product. The ordering pulls "code primitives" before "infra primitives" because primitive bugs are cheaper to fix than infra bugs (no DNS, no Stripe sandbox, no Mailgun in Weeks 1-2).

**Repository layout** (multi-repo, not monorepo):

- `cfpperche/acmeyard` (this repo) — brand + docs/specs/ + portfolio narrative. Unchanged by this plan beyond filling `docs/specs/001-substrate/{plan,tasks,notes}.md`.
- `acmeyard/substrate` (NEW repo) — the Composer package itself.
- `acmeyard/storefront` (NEW repo) — acmeyard.com app (stack decided mid-Week-3 per Open Q #1).
- `acmeyard/fluxo-mei` (NEW repo) — first product template; serves as the `composer create-project` source.

The `acmeyard` GitHub organization is created in Week 3 (parallel with Satis setup); until then, new repos live under `cfpperche/*` and are renamed/transferred to the org when ready. Composer namespace `acmeyard/` is locked early at packages.acmeyard.com via Satis config — GitHub org rename doesn't break Composer URLs.

## Files to touch

### Create — `acmeyard/substrate` repo (NEW)

**Package metadata + tooling:**
- `composer.json` — Laravel package metadata; deps: `laravel/cashier`, `spatie/laravel-multitenancy`, `owen-it/laravel-auditing`, `sentry/sentry-laravel`, `laravel/pulse`, `filament/filament:^3`, `prism-php/prism`; dev-deps: `pestphp/pest`, `laravel/pint`, `phpstan/phpstan`, `larastan/larastan`, `orchestra/testbench`
- `LICENSE.md` — BSL 1.1 (same shape as `/home/goat/acmeyard/LICENSE.md`)
- `README.md` — usage docs + version compatibility matrix
- `CHANGELOG.md` — SemVer changelog scaffold (v1.0.0 placeholder)
- `UPGRADE.md` — empty placeholder; populated on first breaking change
- `pint.json`, `phpstan.neon`, `pest.config.php` — linter/type-checker/test configs
- `.github/workflows/ci.yml` — Pest + Pint --test + PHPStan analyse on PHP 8.3 + 8.4 matrix
- `.gitignore`, `.gitattributes` (Composer artifact filtering)

**Service provider + config:**
- `src/SubstrateServiceProvider.php` — registers all primitives' service bindings, publishes config + migrations
- `config/substrate.php` — `LICENSE_KEY`, `LICENSE_API_URL` (default acmeyard.com), `LICENSE_GRACE_DAYS` (default 14), `BILLING_PROVIDER` (default `stripe`), `AI_PROVIDER` (default `openai`), `TENANCY_MODE` (default `row`)

**Primitive: Auth (Week 1):**
- `src/Auth/SubstrateBreezeServiceProvider.php` — wraps Breeze with substrate conventions (admin guard, license check middleware)
- `src/Filament/SubstratePanelProvider.php` — Filament 3 panel registration; auth-aware

**Primitive: Multi-tenant row-level (Week 1):**
- `src/Tenancy/Tenant.php` — Eloquent model + factory
- `src/Tenancy/Traits/BelongsToTenant.php` — global scope + auto-stamp on create
- `src/Tenancy/Middleware/ResolveTenant.php` — resolves current tenant from auth user → `app('currentTenant')`
- `database/migrations/0001_01_01_000010_create_tenants_table.php`

**Primitive: License-key validator (Week 1):**
- `src/License/LicenseValidator.php` — boot-time check; reads `LICENSE_KEY`, POSTs to validate endpoint
- `src/License/LicenseClient.php` — HTTP client with offline cache (filesystem at `storage/app/substrate/license-cache.json`)
- `src/License/Exceptions/LicenseInvalidException.php`, `LicenseExpiredException.php`
- `src/License/Console/LicenseStatusCommand.php` — `php artisan substrate:license:status`

**Primitive: Billing (Week 2):**
- `src/Billing/BillingProvider.php` — interface (sketch in spec.md Open Q #6; finalize when StripeProvider is written)
- `src/Billing/StripeProvider.php` — concrete impl using Cashier
- `src/Billing/Webhooks/StripeWebhookController.php`
- `database/migrations/0001_01_01_000020_create_subscriptions_table.php`, `..._create_plans_table.php`

**Primitive: LGPD audit (Week 2):**
- `src/Audit/Auditable.php` — re-exports `owen-it/laravel-auditing` trait + substrate defaults (audit user, IP, tenant)
- `database/migrations/0001_01_01_000030_create_audits_table.php` (wraps Spatie's default)

**Transversal: Filament admin (Week 2):**
- `src/Filament/Resources/UserResource.php`, `TenantResource.php`, `LicenseResource.php`, `AuditLogResource.php`, `SubscriptionResource.php`
- `src/Filament/Themes/AcmeYardTheme.php` — base theme (Tailwind tokens shared across portfolio)
- `resources/css/filament/admin/theme.css`

**Transversal: Observability (Week 2):**
- `src/Observability/SentryConfigurer.php` — service provider that no-ops when DSN is empty
- Pulse setup via `composer require` only — no substrate wrapper code needed; Pulse self-installs

**Transversal: AI (Week 2):**
- `src/Ai/AiClient.php` — facade over Prism PHP with `chat()` + `structured(JsonSchema, $prompt)`
- `src/Ai/Structured/JsonSchemaValidator.php` — Prism response → DTO mapping
- `config/ai.php` (published) — provider/model defaults

**Tests (across Weeks 1-2):**
- `tests/Pest.php` — Pest bootstrap, Testbench setup
- `tests/Feature/{Auth,Tenancy,License,Billing,Audit,Ai}/*Test.php` — one test class per primitive, scenarios mirror spec.md acceptance criteria

### Create — `acmeyard/fluxo-mei` repo (NEW, Week 3)

**Composer template:**
- `composer.json` — minimal: `require: laravel/framework: ^11.0, acmeyard/substrate: ^1.0`; `scripts.post-create-project-cmd` runs `php artisan substrate:install`
- `.env.example` — substrate-aware (LICENSE_KEY placeholder, billing/AI provider stubs)
- `app/Models/.gitkeep`, `app/Http/Controllers/.gitkeep`, `app/Filament/Resources/.gitkeep` — empty dirs (anti-goal: no demo screens)
- `bootstrap/providers.php` — registers `SubstratePanelProvider` only

**Deploy artifacts:**
- `Dockerfile` — multi-stage PHP-FPM 8.3 + Nginx
- `docker-compose.yml` — standalone (PostgreSQL + Redis + app)
- `coolify.json` — Coolify-specific deploy hints
- `.github/workflows/ci.yml` — inherited from substrate via `composer create-project` template

**Substrate install command (lives in substrate, runs in fluxo-mei):**
- `acmeyard/substrate/src/Console/InstallCommand.php` — `php artisan substrate:install` publishes config, runs migrations, seeds dev data via `php artisan dev:seed`

### Create — `acmeyard/storefront` repo (NEW, Week 3, stack TBD)

- Landing page (`/`)
- `POST /api/licenses/issue` — Stripe webhook handler; on `checkout.session.completed`, generates HTTP Basic token scoped to `packages.acmeyard.com`, persists to DB, emails customer via Mailgun
- `POST /api/licenses/validate` — substrate's runtime endpoint; checks license validity + tenant + tier
- `POST /api/licenses/revoke` — admin-only; future-proofing

Stack decided mid-Week-3 (Open Q #1). Provisional: **Laravel app + substrate** — the storefront IS itself an acmeyard product (would be product 0 in the portfolio), proves substrate works on the simplest possible case, reuses the substrate's auth + admin + audit + Sentry. Astro/Next.js alternatives in § Alternatives considered.

### Create — Satis private repo (Week 3)

- `packages.acmeyard.com` DNS + TLS (Cloudflare proxy → VPS) — DNS now possible since domain purchased
- VPS or Coolify-hosted Satis instance
- `satis.json` — config pointing at `acmeyard/substrate`, `acmeyard/fluxo-mei`, future products
- HTTP Basic auth tied to license tokens (Satis supports `.htpasswd`-style or custom auth middleware)
- `.github/workflows/release.yml` in substrate repo — on tag, push Composer artifact to Satis index

### Modify — `cfpperche/acmeyard` (this repo)

- `docs/specs/001-substrate/plan.md` (this file) ✅
- `docs/specs/001-substrate/tasks.md` — `/sdd tasks` next
- `docs/specs/001-substrate/notes.md` — populated in-flight during Weeks 1-4
- `README.md` — minor: link to `acmeyard/substrate` repo once it exists, link to https://acmeyard.com once storefront ships
- `.env.example` — N/A (this is a brand repo, not a Laravel app)

### Delete — None

No files removed; this is greenfield. Acme Yard scaffold from initial commit `b4b46e3` stays untouched (it was just an installer artifact for proving Laravel 13.8 boots clean under Agent0 governance).

## Alternatives considered

### Product-first (build Fluxo MEI directly, extract substrate retrospectively)

Rejected because:

1. **Founder-solo cannot extract retrospectively without disrupting a sold product.** Once Fluxo MEI v1 ships and has paying customers, extracting shared code into `acmeyard/substrate` requires a migration in v1.1 — and the BSL license + customer pinning shape means customers may not migrate. The substrate stays orphaned in product 1 forever; product 2 starts from a fresh copy; portfolio cohesion collapses by product 4.
2. **Distribution infra is not extractable.** Satis private repo + Stripe license-issuance webhook + `composer create-project` template flow have no analog in "a Laravel app extracted into a package". Designing them retrospectively means rebuilding what should have been v1 architecture.
3. **License-key validator must exist before product 1 ships.** The validator IS the gate that enforces BSL's Additional Use Grant. Without it, lifetime customers can run the product freely but managed-service offering is unenforceable. Product-first ships before this gate exists.
4. **Spec 047 dogfood prior art.** Agent0 spec 047 (PHP/Laravel support) demonstrated the inverse: when a discipline is needed across multiple forks, designing it once at the substrate level is cheap; retrofitting it into N forks is expensive. The same logic applies here.

The cost of package-first: ~1 week of "product 1 ships slower than if we just started coding Fluxo MEI directly". The benefit: products 2-12 each save ~30-50h of setup, distribution shape works from day 1, license enforcement is real.

### Monorepo at `cfpperche/acmeyard` (substrate + storefront + fluxo-mei in one repo, Turborepo-style)

Rejected because:

1. **Composer `create-project` requires a standalone repo per template.** Cannot ship `apps/fluxo-mei/` subdir of a monorepo as a `composer create-project` source — Composer clones the entire repo. Customer who buys lifetime FluxoMEI would receive a clone with 11 other products' code, defeating "Built to be owned" and possibly violating BSL Additional Use Grant boundaries.
2. **PHP/Laravel monorepo tooling is immature.** No `pnpm workspaces` equivalent that handles Composer dependency resolution cleanly across nested packages without symlink fragility. Spatie publishes ~250 packages and uses single-repo-per-package; this is the canonical Laravel-ecosystem shape.
3. **Substrate evolution cadence ≠ product evolution cadence.** Substrate ships SemVer-strict 1 major/year; products ship features weekly. Mixing them in one repo means every product PR rebuilds substrate test suite. Multi-repo isolates CI cost.

### Sync-harness fork pattern (substrate is a "template Laravel app", products fork + sync one-way, mirror of Agent0 → acmeyard)

Rejected because:

1. **Round 1 discovery confirmed Composer package over fork-with-sync.** User chose `composer create-project` distribution; this plan implements that decision.
2. **PHP has Composer; Agent0 doesn't.** Agent0 is harness-shell-code and there's no package manager for `.claude/hooks/*.sh`, which is why sync-harness exists. Laravel has a mature package manager; using it is idiomatic.
3. **Sync-harness updates are manual; Composer updates are automatic.** Lifetime tier customer pinning `acmeyard/substrate: "1.3.*"` + subscriber running `composer update` is well-understood; sync-harness requires per-fork ratification, friction-heavy at 12 products × N customers.

### Schema-per-tenant multi-tenancy (stancl/tenancy schema mode) instead of row-level

Rejected because: Round 3 discovery — user chose row-level. Schema-per-tenant adds operational complexity (DB migrations × N tenants, backup × N tenants, schema-aware queries) that's only worth it when a product has data-volume scale (Fluxo MEI is unlikely to hit that in year 1). Row-level Eloquent global scope is the idiomatic Laravel pattern (Spatie multitenancy assumes it).

### Built-in BillingProvider abstraction with N concrete providers (Stripe + Pagar.me + EFI + Asaas + Mercado Pago)

Rejected because: Round 3 discovery — substrate ships `BillingProvider` contract + Stripe concrete only. Pagar.me et al. are per-product bindings. Building 5 concrete providers in substrate without product demand is the classic premature-abstraction trap; the contract is the abstraction, the implementation is the product's concern.

### Substrate as OSS published on Packagist public (no Satis, free download)

Rejected because: BSL Additional Use Grant is enforced via license key + private distribution; making substrate freely `composer require`-able from public Packagist defeats the commercial moat. Lifetime tier customers paid for source-available auditability + self-host rights; publishing to public Packagist gives that away. (Substrate becomes Apache 2.0 in 2030 per Change Date; at that point Packagist publication is natural.)

## Risks and unknowns

1. **BillingProvider contract surface unknown until Stripe impl is written.** Mitigation: write `StripeProvider` first (Week 2 Day 1), extract `BillingProvider` interface from the concrete shape (Week 2 Day 2). Iterate when Pagar.me lands in Fluxo MEI Month 1 — the second impl is where the contract gets stressed-tested.
2. **Satis vs Private Packagist deferred decision (spec.md Open Q #2).** Mitigation: Satis is default; switch to Private Packagist (`packagist.com`, ~USD 6.50/user/mo) when paying customers exceed 50. Decide by Week 3 Day 1.
3. **Storefront stack undecided (spec.md Open Q #1).** Mitigation: provisional pick is Laravel app + substrate (dogfoods substrate as product 0). Astro static + serverless webhook is the cheap alternative if Laravel-on-storefront feels like over-engineering. Decide by Week 3 Day 2.
4. **Filament 3 + spatie/laravel-multitenancy compatibility.** Filament was built single-tenant; row-level multi-tenant requires careful global scope handling on Resource queries (Resource lists may bypass `BelongsToTenant` scope if directly querying). Mitigation: Week 1 Day 5 includes a smoke test asserting a Resource list returns tenant-scoped data; if Filament needs explicit `query()` overrides, that's a substrate convention to document.
5. **License-key offline grace period feels-right value unknown.** spec.md Open Q #3. Mitigation: ship with 14-day default; Week 4 dogfood will run Fluxo MEI on a deliberately flaky network for 1 day to validate.
6. **Prism PHP maturity for structured output.** Prism is relatively new (released ~2025). JSON-schema validated structured output may have edge cases. Mitigation: Week 2 includes a Prism integration test calling both OpenAI and Anthropic with the same JsonSchema; capture failure modes as substrate's documented limitations.
7. **BSL + Composer auth.json token UX has no widely-known precedent.** Spatie premium products use a similar pattern but documentation is sparse. Mitigation: Week 3 Day 1 — read Spatie's premium docs + scaffold the auth.json delivery email; iterate if customer feedback in Week 4+ surfaces friction.
8. **Founder-solo time risk.** 3-4 weeks substrate work without paying product = burn-rate without revenue. Mitigation: accepted in the strategic decision to do substrate v1 first; Fluxo MEI in Month 1 resumes revenue. If Week 1 reveals substrate is taking >7 days, replan toward "minimum viable substrate" (drop AI primitive, ship Sentry+Pulse later) rather than slip beyond Month 0.
9. **GitHub org `acmeyard` already exists / taken.** Acme Yard brand chose `acmeyard.com` after `acmeyard.com` was verified available, but GitHub org namespace is separate. Mitigation: check `github.com/acmeyard` availability Week 1 Day 1; if taken, escalate to alternate names (`acme-yard`, `acmeyard-co`) before Week 3 distribution rollout.
10. **Laravel/Filament/Cashier version skew across the 4-week build.** Laravel 11+ → 13 minor releases monthly; Filament 3 → 4 may land in 2026; Cashier track Laravel. Mitigation: lock all deps to specific minor at Week 1 Day 1 in substrate's `composer.json`; bump deliberately at v1.1+.

## Research / citations

Sources informing this plan:

- **`docs/specs/001-substrate/spec.md`** (this fork) — 6-round discovery synthesis. All major decisions traced.
- **`/home/goat/Agent0/docs/specs/047-php-laravel-support/spec.md`** — prior art for Laravel-aware substrate work; established detection signals (`composer.json:laravel/framework`, `artisan`), Pest/PHPUnit dual support, supply-chain blocking for `composer require`.
- **`/home/goat/Agent0/docs/specs/016-harness-sync/*`** — one-way propagation pattern + UPGRADE.md model that substrate's SemVer + UPGRADE.md mirror.
- **`/home/goat/Agent0/.claude/rules/php-laravel-support.md`** — Laravel-canonical detection precedence; informs how substrate's `composer.json` declares dependencies so Agent0 fork detection works correctly.
- **`/home/goat/acmeyard/LICENSE.md`** — BSL 1.1 Additional Use Grant text; constrains license-key validator behavior (fail-open offline grace honors "Built to be owned").
- **Spatie/laravel-multitenancy README** ([github.com/spatie/laravel-multitenancy](https://github.com/spatie/laravel-multitenancy)) — chosen over stancl/tenancy for row-level v1; documents `BelongsToTenant` trait pattern.
- **owen-it/laravel-auditing** ([laravel-auditing.com](https://laravel-auditing.com)) — canonical LGPD audit log package; 10+ years maintained.
- **Laravel Cashier (Stripe) docs** ([laravel.com/docs/billing](https://laravel.com/docs/billing)) — substrate wraps Cashier behind `StripeProvider`.
- **Filament 3 panel registration docs** ([filamentphp.com/docs](https://filamentphp.com/docs)) — informs `SubstratePanelProvider` shape + Resource auto-discovery.
- **Laravel Pulse docs** ([laravel.com/docs/pulse](https://laravel.com/docs/pulse)) — first-party observability; substrate ships baseline cards.
- **Sentry-Laravel** ([docs.sentry.io/platforms/php/guides/laravel](https://docs.sentry.io/platforms/php/guides/laravel)) — DSN-via-env, no-op when unset pattern.
- **Prism PHP** ([prismphp.com](https://prismphp.com)) — multi-provider AI; documents structured output via JSON schema.
- **Composer create-project semantics** ([getcomposer.org/doc/03-cli.md#create-project](https://getcomposer.org/doc/03-cli.md#create-project)) — template repos must be standalone; `post-create-project-cmd` hook runs install command. Confirms multi-repo layout decision.
- **Satis** ([github.com/composer/satis](https://github.com/composer/satis)) — OSS private Composer repo generator; HTTP Basic auth pattern.
- **Spatie premium product distribution** (research target Week 3 Day 1) — the canonical BSL-like Composer-private-distribution UX precedent.
- **Conversation 2026-05-19** (this `/sdd refine` + `/sdd plan` session) — all decisions traced to specific discovery rounds.
