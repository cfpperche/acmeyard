# Acme Yard Project Core

Acme Yard is a portfolio of small, focused SaaS tools for professions that do not usually get great software. The product strategy is "12 ships a year": each microSaaS solves one concrete pain for one specific profession, built on a shared Laravel + Filament substrate and governed by Agent0.

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
