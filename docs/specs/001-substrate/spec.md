# 001 — substrate

_Created 2026-05-19._

**Status:** draft

## Intent

Acme Yard's thesis ("12 ships a year. Built to be owned.") requires that each microSaaS in the portfolio costs hours, not weeks, of substrate work to bootstrap. Without a shared substrate, each of the 12 products carries ~40-80h of boilerplate (auth, billing, multi-tenant scoping, LGPD audit log, license-key validation, observability, admin panel) — 12 × 60h = ~720h/year burned on plumbing, which breaks the monthly cadence the model depends on. This spec defines the substrate v1: a Composer package `acmeyard/substrate` distributed via a private Composer repository (`packages.acmeyard.com` running Satis), consumed by each product via `composer create-project acmeyard/<product>`. The substrate bakes in five load-bearing primitives (auth, pluggable billing, license-key validator, row-level multi-tenancy, LGPD audit log) plus transversal infrastructure (Sentry+Pulse observability, Filament admin with pre-configured resources, Prism PHP chat+structured-output) and a dev toolkit (Pest factories, GitHub Actions CI, portable Docker artifacts). Customer journey: Stripe checkout on acmeyard.com → webhook issues a per-license `auth.json` token → customer runs `composer create-project acmeyard/<product> meu-app` and lands a working Laravel app with green tests, seeded dev data, and Coolify-ready deploy artifacts.

## Acceptance criteria

### Primitives — the five load-bearing modules

- [ ] **Scenario: substrate ships local auth + Filament admin auth**
  - **Given** a fresh `composer create-project acmeyard/fluxo-mei meu-app`
  - **When** the developer runs `php artisan migrate && php artisan serve`
  - **Then** `/login` works for end users (Breeze/Fortify), `/admin/login` works for staff (Filament), users are local-only (no SSO call to acmeyard.com at runtime), and `/admin` panel renders the substrate's pre-registered Resources (User, Tenant, License, AuditLog)

- [ ] **Scenario: BillingProvider contract is swappable**
  - **Given** the substrate's default `App\Substrate\Billing\BillingProvider` bound to `StripeProvider` (Cashier)
  - **When** a product publishes `App\Providers\BillingServiceProvider` that rebinds the contract to `PagarmeProvider`
  - **Then** the product's billing flows route to Pagar.me without modifying substrate code, and substrate Filament Resources (Subscription, Plan) reflect the active provider's data shape

- [ ] **Scenario: license-key validator gates substrate at boot**
  - **Given** a product running with `LICENSE_KEY=<value>` in `.env`
  - **When** the substrate's boot-time validator calls `POST https://acmeyard.com/api/licenses/validate` with the key
  - **Then** valid response unlocks substrate features, invalid response prints a clear error and exits the boot, and a network failure caches the last valid result locally and fails open after a configurable grace period (default 14 days offline)

- [ ] **Scenario: row-level multi-tenant scopes Eloquent models automatically**
  - **Given** the substrate's `Tenant` model + `BelongsToTenant` trait applied to a product's `MeiExpense` model
  - **When** a request authenticated as `tenant_id=A` queries `MeiExpense::all()`
  - **Then** only rows with `tenant_id=A` are returned (global scope active), and a write `MeiExpense::create([...])` automatically stamps `tenant_id=A` without product code setting it explicitly

- [ ] **Scenario: LGPD audit log records PII access automatically**
  - **Given** a product's `Patient` model uses the substrate's `Auditable` trait (spatie/laravel-auditing)
  - **When** a Filament admin user views or modifies a `Patient` record
  - **Then** an `audits` table row is created naming user, model, fields touched, IP, and timestamp; the Filament AuditLog Resource lists the entry within the same request

### Transversal infrastructure

- [ ] **Scenario: Sentry DSN is opt-in via .env**
  - **Given** an empty `SENTRY_LARAVEL_DSN=` in `.env`
  - **When** an exception is thrown in the product
  - **Then** the request errors normally without crashing on Sentry init (no-op), and setting the env var to a real DSN starts capturing exceptions and breadcrumbs

- [ ] **Scenario: Laravel Pulse renders out-of-the-box**
  - **Given** a fresh `composer create-project` install
  - **When** the developer visits `/pulse`
  - **Then** the Pulse dashboard renders with substrate-configured cards (slow queries, queue depth, cache hit rate) and gates access to admin users only

- [ ] **Scenario: AiClient exposes chat + structured-output**
  - **Given** an `OPENAI_API_KEY` (or Anthropic key) in `.env`
  - **When** product code calls `AiClient::chat(['role' => 'user', 'content' => '...'])`
  - **Then** the request routes through Prism PHP to the configured provider; calling `AiClient::structured(JsonSchema::class, $prompt)` returns a validated DTO matching the schema; embeddings and tool-use APIs are NOT exposed at substrate level

- [ ] **Scenario: Filament panel extension is one-line**
  - **Given** the substrate's `Acmeyard\Substrate\Filament\PanelProvider` registered in product's `bootstrap/providers.php`
  - **When** a product's `MeiExpenseResource extends Resource` is auto-discovered under `app/Filament/Resources/`
  - **Then** the resource appears in the same panel as substrate Resources (User, Tenant, License, AuditLog, Subscription), shares the substrate's base theme, and respects the product's panel ordering config

### Distribution + DX

- [ ] **Scenario: Stripe checkout issues a working auth.json token**
  - **Given** a customer pays for a lifetime license at acmeyard.com via Stripe Checkout
  - **When** the Stripe webhook fires `checkout.session.completed`
  - **Then** acmeyard.com generates a per-license HTTP Basic token scoped to `packages.acmeyard.com` and emails it to the customer (Mailgun), and the customer can `composer create-project acmeyard/fluxo-mei meu-app --repository="https://packages.acmeyard.com"` using that token in `auth.json`

- [ ] **Scenario: composer create-project lands a working app in one command**
  - **Given** a customer with a valid `auth.json` token
  - **When** they run `composer create-project acmeyard/fluxo-mei meu-app`
  - **Then** the resulting app passes `php artisan test` (Pest, green), `vendor/bin/pint --test` (green), `vendor/bin/phpstan analyse` (green), and `docker compose up` boots a working stack via the bundled `Dockerfile` + `docker-compose.yml`

- [ ] **Scenario: dev:seed populates substrate primitives with realistic data**
  - **Given** a fresh `composer create-project` install + `php artisan migrate`
  - **When** the developer runs `php artisan dev:seed`
  - **Then** the database contains 1 admin User, 3 Tenants, 1 License (active), seeded AuditLog entries, and 1 sample Subscription — enough to exercise every substrate Filament Resource without manual setup

- [ ] **Scenario: GitHub Actions CI workflow is functional out-of-the-box**
  - **Given** a fresh `composer create-project` install pushed to a new GitHub repo
  - **When** the developer pushes to `main`
  - **Then** the bundled `.github/workflows/ci.yml` runs Pest tests, Pint --test, and PHPStan analyse on PHP 8.3 + 8.4 matrix, and the workflow passes against the unmodified scaffold

### Versioning + dogfood

- [ ] **Scenario: SemVer is strict + 1 major/year max**
  - **Given** substrate releases v1.0.0
  - **When** subsequent releases land within 12 months
  - **Then** every release within v1.x is backward-compatible (minors add features, patches fix bugs), `CHANGELOG.md` records every release, and `UPGRADE.md` exists with migration steps before v2.0 ships

- [ ] **Scenario: dogfood — Fluxo MEI v1 builds on substrate v1 without refactor**
  - **Given** substrate v1.0.0 published to packages.acmeyard.com
  - **When** Fluxo MEI v1 development starts via `composer create-project acmeyard/fluxo-mei meu-fluxo`
  - **Then** the entire Fluxo MEI v1 feature set (Pix-watcher + AI categorization + MEI tax reports) lands as additive code (new migrations, new models, new Filament Resources) without modifying any file in `vendor/acmeyard/substrate/`; substrate v1.1 is acceptable iff at least one Fluxo MEI requirement demands a backward-compatible substrate API addition

### Static facts

- [ ] Composer package `acmeyard/substrate` exists at `https://packages.acmeyard.com` (Satis) and is installable via authenticated `composer require`
- [ ] Template Composer projects exist: `acmeyard/fluxo-mei` (first product, dogfood vehicle); additional `acmeyard/<product>` repos created as each microSaaS lands
- [ ] `acmeyard.com` storefront serves a landing page + Stripe Checkout + Mailgun email integration + license-issuance webhook handler
- [ ] `.github/workflows/release-substrate.yml` validates `composer create-project acmeyard/fluxo-mei` against each substrate PR (green = mergeable)

## Non-goals

- **Multi-provider billing abstraction completa.** Substrate ships `BillingProvider` contract + concrete `StripeProvider`. Pagar.me / EFI / Asaas / Mercado Pago are per-product bindings, not substrate code.
- **SSO / central identity at acmeyard.com.** No `identity.acmeyard.com` SSO server. Cliente self-host never depends on acmeyard.com being reachable at runtime (license validator fails open after grace period). Cross-product identity unification is a managed-cloud-only post-v1 feature.
- **Prism PHP embeddings and tool-use APIs.** Substrate bakes only chat + structured output. Embeddings (needs vector store choice — pgvector / Pinecone / Qdrant) and tool-use orchestration (needs retry / audit infra) become per-product opt-ins when a product demands them.
- **Schema-per-tenant multi-tenancy.** Row-level via `spatie/laravel-multitenancy` is the substrate's only mode. Promoting to schema-per-tenant happens at the product level when a product's data volume justifies it (not a v1 concern).
- **LTS branches (current + N-1 major).** Substrate maintains only the current major. v1.x patches land while v1.x is current; once v2.0 ships, v1.x is frozen.
- **Demo "hello world" screen in `composer create-project`.** Template repos ship empty `app/Http/Controllers/` + `app/Filament/Resources/` so each product author thinks the domain architecture explicitly rather than copy-pasting a hello-world.
- **Customer portal / dashboard / churn-management on acmeyard.com.** v1 storefront is landing + checkout + email token issuance. Customer self-service portal (manage licenses, regenerate tokens, view invoices) is a v2 problem.
- **Multi-provider observability abstraction.** Sentry-only at substrate level. Bugsnag / Honeybadger / Rollbar substitutes are per-product opt-ins if any product demands them.
- **Domain-specific helpers in substrate.** No `MeiExpenseCategorizer`, `DentistAppointmentScheduler`, etc. in `acmeyard/substrate`. Domain logic stays in product packages; substrate stays domain-agnostic.
- **Filament theming infrastructure cross-product.** Substrate ships a single base theme (Acme Yard colors + typography). Per-product theme overrides are allowed but undocumented in v1; if multiple products need different themes, formalize the override surface in v1.1.

## Open questions

- [ ] **Storefront stack for `acmeyard.com`.** Three candidates: (a) Astro static + Stripe Checkout + serverless webhook; (b) Next.js full-stack on Vercel; (c) Laravel app sharing the substrate. Each has different operational cost. Recommendation: defer decision to `plan.md` or a separate sub-spec; substrate v1 only requires the storefront to call back into `acmeyard.com/api/licenses/{validate,issue}` endpoints (any stack can serve those).
- [ ] **Satis vs Private Packagist (paid).** Satis is OSS + free + self-hosted; Private Packagist (`packagist.com`) is SaaS at ~USD 6.50/user/month with better UX (HTTPS, search, audit log out-of-the-box). At <50 paying customers, Satis is cheaper; above that, Private Packagist may be worth it. Decide before Week 3 implementation begins.
- [ ] **License-key grace period default.** Substrate's offline-fail-open period before refusing to boot when acmeyard.com is unreachable. Initial proposal: 14 days. Tradeoff: shorter = better revocation control; longer = better "Built to be owned" promise. Decide via dogfood — what feels right when running Fluxo MEI on a flaky network.
- [ ] **`acmeyard/fluxo-mei` template repo shape.** Two shapes possible: (a) cleanest possible Laravel scaffold with substrate as the only require (one-product-per-template-repo); (b) shared template `acmeyard/product-template` that each product forks at creation. Lean toward (a) for v1 simplicity; revisit if substrate has a lot of per-product boilerplate that template-fork would help share.
- [ ] **CI matrix scope.** Bundled CI workflow tests PHP 8.3 + 8.4. Should it also test against substrate v1.x latest patch? Lean yes — caught-early breaks. Implement during Week 3 if cheap.
- [ ] **BillingProvider contract API surface.** Initial sketch: `subscribe(Plan, Customer)`, `cancel(Subscription)`, `invoice(Subscription)`, `webhookHandler(Request)`. Refine when Stripe-default implementation is being written, NOT speculatively before.

## Context / references

- **`/home/goat/acmeyard/README.md`** — Acme Yard brand pitch, 3-tier distribution shape, stack declaration. Establishes the constraints the substrate must respect.
- **`/home/goat/acmeyard/LICENSE.md`** — BSL 1.1 license + Additional Use Grant. Constrains: managed-service offering for third parties NOT permitted, lifetime self-host + non-production allowed. License-key validator must honor "Built to be owned" via fail-open offline grace.
- **Agent0 spec 047 (`php-laravel-support`)** — `/home/goat/Agent0/docs/specs/047-php-laravel-support/spec.md`. Substrate inherits all 7 PHP/Laravel-aware Agent0 capacities (validator picks Pest, supply-chain blocks `composer require`, runtime-introspect captures phpunit/pest snapshots, lint runs Pint + PHPStan).
- **Agent0 spec 016 (`harness-sync`)** — one-way propagation pattern + `UPGRADE.md`-as-guide model that substrate's SemVer + UPGRADE.md mirror.
- **`.claude/rules/php-laravel-support.md`** in this fork — synced from Agent0 spec 047; documents the runtime/validator behavior the substrate will exercise on every push.
- **stancl/tenancy** — schema-first multi-tenant package. Considered and rejected for substrate v1 in favor of row-level (per Round 3 discovery).
- **spatie/laravel-multitenancy** — row-level multi-tenant package; expected substrate dependency.
- **spatie/laravel-auditing** — LGPD audit log baseline; expected substrate dependency.
- **Laravel Cashier (Stripe)** — billing baseline; expected substrate dependency wrapped by `StripeProvider`.
- **Laravel Pulse** — first-party observability; expected substrate dependency.
- **sentry/sentry-laravel** — error tracking; expected substrate dependency (no-op when DSN unset).
- **Filament 3** — admin panel; expected substrate dependency.
- **Prism PHP** — multi-provider AI abstraction; expected substrate dependency for `AiClient` wrapper.
- **`laravel/boost` MCP** — Agent0 spec 047 § MCP recipes added this recommendation; install at the substrate level once distribution is live so each product's `composer create-project` includes the MCP block in `.mcp.json.example`.
- **Conversation 2026-05-19 (this discovery session)** — 6 rounds of `/sdd refine substrate` decisions feeding this spec. Decisions: substrate primitives count (3 → 5 after multi-tenant promoted + LGPD audit baked); Composer create-project as distribution; private Satis repo; license-key token issuance via Stripe webhook; BillingProvider swappable contract; row-level multi-tenant by default; Sentry+Pulse observability; Filament substrate-default; Prism chat+structured baseline; SemVer strict + 1 major/year; toolkit complete in create-project.
