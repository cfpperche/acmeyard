# Acme Yard

> **12 ships a year. Built to be owned.**

A portfolio of small, focused SaaS tools for professions that don't usually get great software — built on a shared Laravel + Filament substrate, AI-governed by Agent0, and shipped under a license that lets you self-host what you pay for.

## What this is

Each microSaaS in Acme Yard solves one concrete pain in one specific profession (dentist, food truck operator, condomínio síndico, conselheiro tutelar, small CSA farmer, doula, paralegal, K-12 sysadmin, …). The first product is a fluxo-de-caixa for Brazilian MEIs with Pix integration and AI-categorised expenses; the catalog grows by one per month.

All products share:

- The same engineering substrate (auth, billing, multi-tenant, LGPD audit log, AI provider abstraction)
- The same distribution shape — see *Distribution* below
- The same governance discipline from [Agent0](https://github.com/cfpperche/Agent0) (validator, supply-chain gate, runtime introspection, license-key system)

## Distribution

Three tiers per product:

| Tier | Who buys | What they pay |
|---|---|---|
| **Self-host lifetime** | Devs, technical consultancies, indie operators | One-time, ~BRL 497 / USD 297 |
| **Self-host + update subscription** | Same buyer, wants ongoing improvements | Lifetime + ~BRL 47 / USD 47/mo opt-in |
| **Managed cloud** | Non-technical PME owners, enterprise | ~BRL 197 / USD 197/mo |

The Business Source License (see [LICENSE.md](./LICENSE.md)) allows free non-production and personal self-hosted use. Commercial managed-service offerings — running Acme Yard's products for third parties — require a commercial license. Four years after each release the code becomes Apache 2.0.

## Stack

- **Laravel 11+** — framework substrate (auth, queues, scheduling, broadcasting)
- **Filament 3** — admin panel + RBAC + audit log surfaces
- **Livewire 3** — interactive UI without SPA assembly cost
- **Laravel Cashier** — Stripe + Paddle billing
- **stancl/tenancy** — schema-per-tenant multi-tenant
- **Prism PHP** — multi-provider AI abstraction (Anthropic, OpenAI, Mistral, local)
- **Coolify** — Docker-based deployment (same artifact for self-host and managed cloud)

Brazilian-context libraries: `efí-pix` / `gerencianet` for Pix, `laravel-cnpj` + `laravel-cpf` for fiscal validation.

## Status

Scaffolding. Substrate work begins as the first spec in `docs/specs/001-substrate/`. Track progress in commit history; each product ships as its own subfolder under `apps/` (or as a sibling repo, TBD during substrate spec).

## Acme Yard ⇄ Agent0

This repository is operated under the [Agent0](https://github.com/cfpperche/Agent0) governance harness — every sub-agent edit passes through a post-edit validator, every `composer require` writes an audit row, every `vendor/bin/phpunit` run is captured for the agent's edit-verify loop. The `.claude/` directory is synced one-way from Agent0 via `sync-harness.sh`; see [`CLAUDE.md`](./CLAUDE.md) for the full capacity inventory.

## License

Business Source License 1.1 (BSL 1.1) → Apache 2.0 on 2030-05-18. See [LICENSE.md](./LICENSE.md) for parameters and the canonical license text.

## Contact

- Issues, ideas, bug reports: GitHub Issues
- Commercial licensing: cfpperche@gmail.com
