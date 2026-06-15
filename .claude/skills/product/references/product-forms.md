# Product forms — form-factor taxonomy + per-form variant surfaces (v0.6.0)

`/product` no longer assumes every product is a screen-based web app. Step 01 (ideation) classifies the product's **form factor**; the orchestrator mirrors it to `.state.json.product_form`; four downstream surfaces read it at dispatch time and adapt. The completeness discipline (the anti-silent-undercoverage lesson behind `sitemap-schema.md § required_categories`) is preserved for every form — only the *ruler* changes, never the existence of the check.

## The taxonomy

| Form | One-line definition | Examples |
|---|---|---|
| `screen-app` | The user interacts through screens the product owns (web, mobile, desktop) | SaaS dashboard, mobile habit tracker, ERP |
| `headless-service` | Consumed by other programs; the product surface is an API + its docs | payments API, data enrichment service, webhook relay |
| `cli` | The interface is a terminal: commands, flags, output streams | dev tool, scaffolder, ops utility |
| `bot` | Lives inside a messaging/voice platform; the surface is conversation turns | WhatsApp assistant, Slack bot, voice agent |
| `embedded` | Ships inside a host platform's UI chrome (extension, plugin, add-on) | browser extension, Figma plugin, Shopify app block |

**Classification rule (Step 01):** pick the form where the *primary* user value is delivered. A SaaS with a small API picks `screen-app`; an API with a small status page picks `headless-service`. Hybrids pick the dominant surface and note the secondary one in the concept brief. When genuinely ambiguous, the Step 01 producer states its choice + rationale and the concept gate (`gate_concept`) is the founder's chance to correct it.

**Binding + mirroring:** the concept brief's `§ Product Form` section is the human-readable declaration (form + 1-3 line rationale). After Step 01 returns, the orchestrator copies the form value into `.state.json.product_form` (see `state-machine.md`). Immutable once set — a different form is a different product; start a fresh run.

## Variant surface map

Exactly four surfaces vary by form. Everything else in the 15-step pipeline (PRD, OST, system design, legal, roadmap, cost, GTM, brand) is form-neutral and unchanged.

### Step 07 — completeness category set (`sitemap.yaml` `required_categories`)

The orchestrator's post-Step-07 enforcement (parse + BLOCK on uncovered category without a `deferred_categories` declaration — `sitemap-schema.md`) is identical for every form. The category set it enforces resolves from this table:

| Form | `required_categories` | The inventory unit (`routes` mean…) |
|---|---|---|
| `screen-app` | `[marketing, auth, primary, admin, error]` | screens/pages (unchanged from v0.5.0) |
| `headless-service` | `[docs, auth, endpoints, admin, errors]` | API endpoints + the developer-facing surfaces (reference docs, key management, error catalog) |
| `cli` | `[install, commands, config, output, errors]` | commands/subcommands + install & config surfaces + output/exit-code contract |
| `bot` | `[onboarding, intents, fallbacks, admin, errors]` | conversation intents/flows + the first-contact flow + out-of-scope handling |
| `embedded` | `[listing, install-grant, primary, settings, errors]` | host-platform touchpoints: store listing, permission grant, in-host panels/commands |

Per-route field set (`path / category / states / covers_us / components`) keeps its shape; for non-screen forms `path` holds the endpoint/command/intent identifier and `components` the reusable building blocks of that form (response schemas, flag conventions, message templates).

### Step 02 — lo-fi mood variant

All forms still produce static HTML at `docs/screens/` (HTML is the rendering medium, not a claim that the product has screens), so the craft-floor check and judge plumbing are unchanged:

- `screen-app` — UI mood screens (unchanged).
- `headless-service` — a developer-experience walkthrough: quickstart page mock + annotated request/response exchanges for the killer flow.
- `cli` — terminal-session mockups: the killer flow as styled session transcripts (prompt, command, output).
- `bot` — conversation mockups: the killer flow as a styled message thread in the host platform's visual idiom.
- `embedded` — host-chrome mockups: the product's panels/menus drawn inside a neutral sketch of the host UI.

### Step 14 — design-system scope

- `screen-app` — full scope (unchanged): tokens.css + components.md + README.
- `headless-service` — tokens scoped to docs/code-sample styling; components.md catalogs API conventions (naming, pagination, error envelope) instead of UI components.
- `cli` — tokens scoped to terminal palette + typography of docs; components.md catalogs output conventions (tables, progress, error format, exit codes).
- `bot` — tokens scoped to rich-message styling where the platform allows; components.md catalogs message templates + tone patterns (brand voice is load-bearing here).
- `embedded` — tokens constrained to the host platform's design language; components.md catalogs the in-host components + the host style-guide deltas.

### Phase 4 — the contract artifacts (15a / 15b / 15c)

The three judge-units keep their names, paths, and floors; their *content* is the form's interface contract:

| Form | 15a `screen-atlas.md` indexes… | 15b `screens/hifi/*.html` renders… | 15c `fixture-spec.md` fixes… |
|---|---|---|---|
| `screen-app` | every sitemap route + states + PRD coverage (unchanged) | brand+tokens killer-flow screens (unchanged) | one persona + coherent entity set (unchanged) |
| `headless-service` | every endpoint: auth, params, responses, error envelope, PRD coverage | brand-styled docs pages for the killer flow (quickstart + annotated exchanges) | one tenant + API keys + coherent request/response payloads |
| `cli` | every command: flags, stdin/stdout contract, exit codes, PRD coverage | brand-styled killer-flow session transcripts | one project context + file tree + deterministic command outputs |
| `bot` | every intent: triggers, slots, replies, fallback paths, PRD coverage | brand-styled killer-flow conversation threads | one user + conversation history + platform metadata |
| `embedded` | every host touchpoint: entry points, permissions, panels, PRD coverage | brand-styled killer-flow panels in host chrome | one host account + workspace state |

The SDD handoff (Phase 5) is form-neutral: the umbrella's standing constraints cite this file's row for the declared form, and built-UI acceptance is a green project UI test (see `.agent0/context/rules/ui-acceptance.md`) wherever the built product has a drivable surface.

## Adding a form

New forms are added here (one taxonomy row + four variant entries) — never inline in briefs or SKILL.md. A form without all four variant entries is not shippable. `screen-app` is the reference row: its entries must stay behavior-identical to /product v0.5.0.
