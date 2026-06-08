# Acme Yard Project Core

<!-- AGENT0:PROJECT-CORE-TEMPLATE: 2026-06-08-1 -->

Acme Yard is a portfolio of small, focused SaaS tools for professions that do not usually get great software. The product strategy is "12 ships a year": each microSaaS solves one concrete pain for one specific profession, built on a shared Laravel + Filament substrate and governed by Agent0.

## Language & Locale

- Human communication: follow the user's language; use pt-BR when the user writes in Portuguese.
- Repository artifacts: English for README, architecture notes, specs, commits, code comments, and technical docs unless a task explicitly targets localization.
- Existing files: preserve the surrounding language unless the task is translation/localization.
- Brazilian context: Pix, CPF/CNPJ, LGPD, BRL, and Brazilian professional workflows matter when the active product/spec targets Brazil; do not infer a global product-copy language from that alone.
- Ambiguous new user-facing or externally published text: ask before choosing a locale.

## Stack

- Laravel 11+ application substrate with queues, scheduling, auth, and billing surfaces.
- Filament 3 and Livewire 3 for operational UI.
- Laravel Cashier, Stripe/Paddle, and `stancl/tenancy` for commercial SaaS primitives.
- Prism PHP for multi-provider AI abstraction.
- Brazilian-context integrations matter: Pix, CPF/CNPJ validation, LGPD auditability, and Portuguese-language product workflows.

## Operating Notes

- Treat Agent0 harness files as governance/tooling, not product code.
- Product work should land under specs in `docs/specs/` and keep Laravel conventions intact.
- The repository is currently scaffolding; substrate work begins from `docs/specs/001-substrate/` when product implementation resumes.
- The license posture is BSL 1.1 with Apache 2.0 conversion; avoid advice or changes that weaken the commercial managed-service boundary.
