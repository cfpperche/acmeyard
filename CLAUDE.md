# Acme Yard

Acme Yard is a portfolio of small, focused SaaS tools for professions that do not usually get great software. It is built on a shared Laravel + Filament substrate, governed by the Agent0 harness, and distributed through self-host and managed-cloud tiers.

## Overview

Each Acme Yard microSaaS solves one concrete pain for one specific profession. The first product target is fluxo-de-caixa for Brazilian MEIs with Pix integration and AI-categorised expenses; future products share the same auth, billing, tenancy, audit, and AI-provider substrate.


## Stack

- Laravel 11+
- Filament 3
- Livewire 3
- Laravel Cashier with Stripe/Paddle
- `stancl/tenancy`
- Prism PHP
- Brazilian fiscal/payment integrations where relevant: Pix, CPF/CNPJ validation, LGPD audit logs


## Build & test

```bash
composer test
php artisan test
npm run build
```


## Conventions

- Product work is spec-first under `docs/specs/`.
- Keep Laravel and Filament conventions intact unless a spec explicitly justifies a deviation.
- Treat the Agent0 harness as governance/tooling. Product code lives in the Laravel app surface, not in harness directories.


## Gotchas

- Acme Yard is commercially licensed under BSL 1.1 with Apache 2.0 conversion; preserve the managed-service commercial boundary.
- The repository is currently scaffolding. Substrate work starts from `docs/specs/001-substrate/`.

<!-- AGENT0:PROJECT:BEGIN -->
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
<!-- AGENT0:PROJECT:END -->

<!-- AGENT0:BEGIN -->

## Spec-driven development

Non-trivial work is spec-first — intent before code under `docs/specs/NNN-<slug>/{spec,plan,tasks,notes}.md`, scaffolded and progressed by the `/sdd` skill. See `.agent0/context/rules/spec-driven.md`.

## Runtime entrypoints

`CLAUDE.md` is the Claude Code entrypoint; `AGENTS.md` is the Codex entrypoint. This managed block is the shared Agent0 index; runtime support details live in `.agent0/context/rules/runtime-capabilities.md`. `AGENTS.md` is baseline-tracked; Codex consumer project customization belongs in `AGENTS.override.md` or nested `AGENTS.md`.

## Runtime capabilities

`.agent0/context/rules/runtime-capabilities.md` is the canonical provider-neutral matrix for Agent0 capability support across Claude Code, Codex CLI, and future runtimes. Consult it before assuming a `.claude/*` capability is native in a runtime. **Never assert that a built-in command (e.g. a slash command like `/goal`) does not exist just because it is absent from your skills list — the injected inventory is not exhaustive; hedge and verify instead (see the rule's § Before claiming a capability or command does NOT exist).**

## Session handoff

`.agent0/HANDOFF.md` is the canonical runtime-neutral handoff with four sections: Current State, Active Work, Next Actions, Decisions & Gotchas. Claude Code injects/nags through hooks; Codex receives the same handoff through tracked `.codex/hooks.json`, with `AGENTS.md` as the convention fallback. See `.agent0/context/rules/session-handoff.md`.

## Delegation

`Agent` dispatches are gated: `.agent0/hooks/delegation-gate.sh` enforces a 5-field handoff (TASK / CONTEXT / CONSTRAINTS / DELIVERABLE-or-DONE_WHEN), and `.agent0/hooks/delegation-verify.sh` verifies sub-agent work at close (`SubagentStop`, runtime-neutral). See `.agent0/context/rules/delegation.md`.

## User prompt framing

On a non-trivial prompt the main agent runs a 3-question mental check (TASK / CONTEXT / DONE clear?) and clarifies via `AskUserQuestion` before acting when ≥2 are unclear. Rule-only — no hook. See `.agent0/context/rules/user-prompt-framing.md`.

## Test-driven development

Production code follows red → green → refactor with tests in the same diff; the validator emits a non-blocking `tdd-advisory:` when prod files move without a test. Cultural discipline, not a blocking gate. See `.agent0/context/rules/tdd.md`.

## Secrets scan

Two layers — the native `.githooks/pre-commit` runs gitleaks over the staged diff at commit time; a runtime-neutral `PreToolUse(Bash)` preflight (`.agent0/hooks/secrets-preflight.sh`) gates dangerous commit shapes on Claude Code and Codex CLI. Activate per-consumer with `git config core.hooksPath .githooks`. See `.agent0/context/rules/secrets-scan.md`.

## Vuln audit

`.agent0/tools/vuln-audit.sh` (engine osv-scanner) detects known-vulnerable INSTALLED dependencies on demand, stack-aware, runtime-neutral. Codex invokes the tool directly: `bash .agent0/tools/vuln-audit.sh [path] [--json] [--exit-code] [--severity <level>]`. Don't gate install/commit — detect vulnerable locked libs and act; reports + proposes, never auto-fixes. See `.agent0/context/rules/vuln-audit.md`.

## MCP recipes

MCP server blocks for common external MCPs (Playwright, Chrome DevTools, DBHub, Laravel Boost, Next.js DevTools, fal.ai) ship as copy-paste templates only: `.mcp.json.example` for Claude Code, `.codex/config.toml.example` for Codex CLI. Each block is `enabled = false` / commented by default and uses env-var indirection for any secret (`bearer_token_env_var`, `env_vars`). Consult the upstream README of each MCP for activation specifics, runtime requirements, and security stance — Agent0 ships the templates, not curated reference docs.

## Image generation

Opt-in capacity for AI image generation via fal.ai MCP — the `/image` skill produces draft mockups (FLUX schnell, ~$0.003/img, gitignored) and brand assets (gpt-image-2 or Imagen 4 Ultra, $0.04-$0.20/img, tracked) with mandatory `--tier` flag, pre-call cost printing, and a gitignored local JSONL manifest of every call. Activation is a `.mcp.json` edit + `FAL_KEY` env. See `.agent0/context/rules/image-gen.md`.

## Video generation

Opt-in capacity for video, sibling to `/image`. The `/video` skill has two disjoint modes behind a required `--mode` flag: `code` (deterministic — HyperFrames renders an HTML/CSS/JS composition to MP4 locally, zero inference cost, source git-tracked) and `generative` (paid, async — fal.ai video models via the queue REST API, fire-and-forget ledger, hard `--confirm-cost-usd` gate). Activation is per-mode: code needs Node 22+/ffmpeg/headless-Chrome; generative needs `FAL_KEY`. Ships mechanisms, not model IDs — generative tiers resolve from a refreshable `video-tiers.yaml`. See `.agent0/context/rules/video-gen.md`.

## Transcribe

Opt-in local-first speech-to-text — the `/transcribe` skill (+ runtime-neutral `.agent0/tools/transcribe.sh`) turns an audio OR video file into a transcript via whisper.cpp (MIT), **locally**: the audio/video content never leaves the machine, only model weights are fetched once. Deliberately NOT paid media (no cost/tiers/key) — a local utility in the `vuln-audit` class (on-demand, single-engine, result-status decoupled from exit code, reports-never-blocks), with a **provenance** manifest not a cost ledger. Auto-acquires engine + `base` model as invisibly as possible (uvx ladder), degrading to a one-line hint. All native transcript formats are selectable (txt default; thin passthrough contract); diarization is the named paid-STT reopen-trigger. Recognition sibling of the synthesis-side `/audio`; split by output ontology. See `.agent0/context/rules/transcribe.md`. (spec 159)

## Audio

Opt-in text-to-speech synthesis — the `/audio` skill (+ runtime-neutral `.agent0/tools/audio.sh`) turns text into spoken audio, **local-first and free by default**. Synthesis sibling of `/transcribe` (split by output ontology). Two on-device engines (Kokoro default — multilingual incl. pt-BR, best quality, but needs the `espeak-ng` system binary; Piper — self-contained, 900+ EN voices, the more-portable fallback), user-installed + subprocess (GPL-via-aggregation, never bundled). Optional paid upgrade via fal (`--remote`, ElevenLabs-only tiers — the paid lane offers what local can't; cost printed before, no hard gate). Two output classes like `/image` (gitignored draft vs tracked `assets/audio/` voiceover); hybrid manifest (provenance for local + cost for paid); `stayed_local` honest per lane (`FAL_KEY` never printed). NOT music/SFX, NOT voice cloning (deferred). See `.agent0/context/rules/audio.md`. (spec 160)

## Sound

Opt-in **paid-only** creative-audio generation — the `/sound` skill (+ runtime-neutral `.agent0/tools/sound.sh`) generates **music + sound effects** from a text prompt. The creative-asset member of the audio family: it is the **`/image brand` analog**, NOT the local-first `/audio` analog — music/SFX has no light local engine, so `/sound` is openly paid (`stayed_local:false` always; no free lane — `FAL_KEY` absent → honest `unavailable`). Kept a separate skill so `/audio`'s local-first identity stays coherent. `--kind music|sfx` required. Tier→model + body shape + output url path + price resolve from a **data-driven `sound-tiers.yaml` oracle** (because body/url shapes differ per model — CassetteAI `audio_file.url` vs ElevenLabs `audio.url`; a new model is a yaml edit, not code). **Hybrid cost gate** (printed before every call + hard `--confirm-cost-usd` above $0.25 — clips cost 100× a TTS call). **Taste-judged** (one generation → gitignored draft to listen to → human promotes a keeper with `--asset`; no auto-done). Two output classes + hybrid manifest like `/audio`. NOT TTS (`/audio`), NOT transcription (`/transcribe`), NOT editing/mixing, NOT lyrics-to-vocals, NOT voice cloning. See `.agent0/context/rules/sound.md`. (spec 161)

## Diagram

Opt-in **deterministic technical-visual generation** — the `/diagram` skill (+ runtime-neutral `.agent0/tools/diagram.sh`) compiles a **Mermaid** text source (file or inline) into a tracked SVG/PNG/PDF (architecture, flowchart, sequence, ER, class, state). The **deterministic sibling of `/video --mode code`** and the **technical-visual counterpart to `/image`** (organic/photo, paid) — a **`/transcribe`-class LOCAL/FREE utility** (provenance manifest, no cost ledger, no `FAL_KEY`/tiers; `stayed_local:true`). Render via `mmdc` (`@mermaid-js/mermaid-cli`) acquired by **npx** (no global install) reusing **system Chrome** (puppeteer config + `PUPPETEER_SKIP_DOWNLOAD=1`); when Chrome is absent it **degrades to validation-only** (Chrome-less structural check + tracked source kept, `status=unavailable` — never a dead capacity). **Mermaid-only v1** (d2 is a documented reopen-trigger if Chrome-dep pain dominates). Diagrams are **keepers** — `.mmd` source + rendered asset are git-tracked (default `assets/diagrams/`, spec-owned via `--out docs/specs/NNN/diagrams/`); only the manifest is gitignored. NOT organic imagery (`/image`), NOT motion (`/video`), NOT design craft (`/frontend-designer`), NOT a GitHub-README-renderer replacement. **Consumer harness-sync gated on a v1 dogfood** (minority report). See `.agent0/context/rules/diagram.md`. (spec 162)

## Capacity kit

`.agent0/tools/lib/capacity.sh` is the shared **kernel** the capacity tools (`audio`/`sound`/`transcribe`/`diagram`, + future) `source` instead of hand-copying plumbing — `cap_have`/`cap_sha256_*`/`cap_emit_exit` (status→exit) /`cap_manifest_append` (one-line JSONL mechanic) /`cap_fail` (with a `_cap_on_fail` manifest hook) /`cap_resolve_ffmpeg`. A small helper lib, NOT a framework — each tool keeps its own flow, args, `doctor`/`caps`, manifest schema, engine, storage. Convention: the tool sets `CAP_TOOL`/`USE_EXIT_CODE`/`OUT_JSON`; extract only byte-identical-or-cleanly-parameterized plumbing (a tool with a richer/ pretty failure JSON keeps its local `fail`). The **paid-media sub-kit** `.agent0/tools/lib/paid-media.sh` (spec 164) is the companion for the PAID tools — **four PURE helpers** (`pm_yaml_top`/`pm_yaml_tier_field` tiers-oracle reader + leak-safe `pm_has_fal_key`/`pm_fal_key_state`), a separate lib (not folded — paid-domain cohesion), consumed by all four paid tools: `sound` + `audio --remote` (tools-dir, file-top source) and `video` + `image` (**skill-dir, cross-dir lazy-load** — spec 165). `video` takes `pm_yaml_*` + `pm_has_fal_key`; `image` takes `pm_has_fal_key` only (pipe-table tiers stay). **Cross-dir pattern (165):** skill-dir tools source `. "$PROJECT_DIR/.agent0/tools/lib/paid-media.sh"` (the anchor they already use for `fal-rest.sh`), **lazy-loaded inside paid subcommands only** so `--help`/`noargs`/`record` work lib-absent; absent → `exit 70` on the paid path. Honest scope: cost-formula + `--confirm-cost-usd` gate + fal invocation stay LOCAL; `image` pipe-table→YAML out (creates surface, retires nothing). **Local acquisition ladders stay per-tool templates.** Propagates via the `.agent0/tools/lib|*.sh` sync glob (load-bearing). Behavior-preserving by contract, proven by `golden.sh` (FAL_KEY-hermetic) + `paid-golden.sh` + `cross-dir-source.sh` + each tool's suite + sync-propagation + missing-kit-guard. See `.agent0/context/rules/capacity-kit.md`. (specs 163, 164, 165)

## Harness sync

`.agent0/tools/sync-harness.sh` brings a consumer project's harness up to date with Agent0 via 3-way baseline reconciliation against `.agent0/harness-sync-baseline.json` — stale files auto-update, consumer-customized files refuse without `--force`, never touches product code. See `.agent0/context/rules/harness-sync.md`.

## Lint validator

The post-edit validator runs the consumer project's idiomatic linter — Biome (JS/TS), Ruff (Python), Pint + PHPStan/Larastan (PHP) — when the manifest declares it; missing-but-declared emits a non-blocking `lint-advisory:`. See `.agent0/context/rules/lint-validator.md`.

## Typecheck advisory

The validator runs a typecheck step only when the consumer project declares the primitive (a `tsconfig.json`, or a `typecheck` script in `package.json`); otherwise it emits `typecheck-advisory:` and skips. See `.agent0/context/rules/typecheck-advisory.md`.

## Memory

Factual project knowledge lives in `.agent0/memory/<topic>.md`; the trigger-read index is `.agent0/memory/MEMORY.md`. Content is git-tracked for this project, but not shipped to consumers.
Read the index when work touches project architecture, first-party capacities, `.agent0/context/rules/`, `.agent0/hooks/`, `.claude/skills/`, `.agent0/tools/sync-harness.sh`, `.agent0/context/rules/runtime-capabilities.md`, or `.agent0/memory/`.
Follow only relevant entries; ordinary reads do not mutate memory.
Claude uses `.claude/settings.json` hooks. Codex uses tracked `.codex/hooks.json` hooks after the project and changed hook definitions are trusted.
Do not raw-edit `.agent0/memory/MEMORY.md`; edit entries and let projection regenerate it.
Hook-disabled memory edits must end with `bash .agent0/tools/memory-maintain.sh finalize <entry-path>`.
Without hooks, stale-memory readout is `bash .agent0/tools/memory-query.sh decay --readout`.
See `.agent0/context/rules/memory-placement.md` § Multi-runtime usage.

## Context retrieval

`.agent0/tools/context-retrieve.sh search --query "<text>"` performs deterministic local retrieval across Agent0 context rules, project memory projection/metadata, specs, and handoff. `context-inject.sh` uses it as a bounded retrieval lane after deterministic rule selection: existing rule matches form a must-include floor, retrieval fills only remaining prompt budget, and snippets are pointers rather than source of truth. No embeddings/vector DB in v1. See `.agent0/context/rules/context-retrieval.md`.

## Status & doctor

Two on-demand, text-first shell tools over live harness state (the transferable kernel of `opus-domini/sentinel`, ported to a repo harness). `status` (`/status`, or `bash .agent0/tools/status.sh`) is the untruncated mid-session sibling of the SessionStart brief — handoff, reminders, routines, decay, git state, suggested next commands; read-only, always exit 0. `doctor` (`bash .agent0/tools/doctor.sh`) reports harness health (files/hooks/binaries/`core.hooksPath`) with a tri-state per check, exit non-zero only on `broken`; reports, never fixes. Both reuse `.agent0/hooks/_brief-compose.sh`. NOT a browser/daemon/metrics surface — the anti-drift scope is load-bearing. See `.agent0/context/rules/agent0-status.md`.

## Browser primitive

`agent-browser` (vercel-labs native-Rust CLI) is the **primary, runtime-neutral agent browser primitive** — eyes + hands + observe driven through plain shell (no per-runtime MCP wiring). First-party work goes through `.agent0/tools/agent-browser.sh`, which adds the operational envelope: binary/Chrome detection (`caps`), deterministic fail-closed routing (`route` → `primary`, else `unavailable:{no-binary,no-chrome,mcp-removed}` and commands fail closed — no MCP fallback, spec 153), a policy-as-file guard + per-command audit (`run`), a bounded visual-contract verifier (`verify-contract`), and daemon-lifecycle ownership (`reset`). Playwright + Chrome DevTools MCP survive only as opt-in `.mcp.json.example` / `.codex/config.toml.example` templates — **not** a harness fallback (spec 153); when the binary is absent, first-party browser work fails closed. Opt-in install; `doctor.sh` reports availability; profiles/saved state are credential-class. **Attempt-before-handoff:** before asking a human to do browser work ("abra essa URL e confira"), drive it via agent-browser or prove an *observed* unavailability/blocker — delegate only the smallest genuinely human-only sub-step, with evidence; never punt by reflex. See `.agent0/context/rules/browser-primitive.md` § Attempt-before-handoff. (spec 152 + 153)

## Browser auth

On an auth-gated URL with no saved state the agent emits `BROWSER_LOGIN_REQUIRED: <host>`; the human runs `bash .agent0/tools/browser-login.sh <host>` and logs in, then the agent attaches over CDP via `agent-browser.sh adopt <host>` and saves state to `.agent0/.runtime-state/agent-browser/state/<host>.json` for headless reuse. **agent-browser-native; no MCP path (spec 153).** See `.agent0/context/rules/browser-auth.md`.

## Visual contract acceptance

When a spec/task produces UI, "done" is proven by **driving the UI**, not static review. A `**UI impact:** none|render|interaction|flow` declaration triggers a **visual contract** — an interaction-trace acceptance artifact (render → interaction → flow tiers, semantic DOM/a11y/route/state assertions, not pixel-diff) run via the existing `agent-browser.sh verify-contract` and proven in the delegation gate's `DONE_WHEN` (no 6th field). `.agent0/tools/ui-impact-detect.sh` + the validator emit a non-blocking `visual-contract-advisory:` when a UI surface changes without a declaration or when a declared UI change lacks a passing `report.json`; v1 is advisory (tdd/lint/typecheck precedent), `agent-browser` unavailable ≠ pass. Reconciles with `/product`'s design-time contract as its implementation-evidence counterpart. See `.agent0/context/rules/visual-contract.md` (spec 155).

## Skill compliance

Every first-party `.claude/skills/*/SKILL.md` must pass the agentskills.io frontmatter spec; the `/skill` meta-skill scaffolds, audits, ports, and validates them, with three declared portability tiers. See `.claude/skills/skill/`.

## Product skill

`/product` is the foundation generator + design partner for the product lifecycle (idea → v1 → vN) — a multi-step industry-aligned pipeline producing the planning artifacts + a visual contract that hands off to SDD. See `.claude/skills/product/`.

## Frontend designer

`/frontend-designer` is the build-time **craft loop** — the "artist" that designs or refines a *real, runnable* frontend with taste, filling the gap between `/product` (planning, no runnable app) and the spec-155 visual-contract gate (acceptance). Three modes: `create` (greenfield UI slice in the project's stack), `refine` (improve existing UI — bounded diff, before/after evidence, preserved behavior), `explore` (research + design-direction only, no code). Always researches references first and writes a git-tracked `reference-research.md` + `design-direction.md` pair. Detects and adapts to the project's stack via a project-derived ladder (no frozen defaults); reuses the existing design system before inventing. Done-proof reuses spec 155 — browser-renderable output proven by a green `agent-browser verify-contract` report; **agent-browser unavailable is a blocker, never a pass**; native-only surfaces use honest, labeled evidence and add no new native visual tooling. The "artist" is context-engineering (no persona), bounded by explicit stop criteria. Deterministic mechanics in `scripts/frontend-designer.sh` (`caps|detect|artifacts-dir|scaffold-docs|verify`). Graduated from a decision-grade `/meeting`; built as spec 158. See `.agent0/context/rules/frontend-designer.md`.

## Meeting

`/meeting` convenes a multi-party, multi-model deliberation — a human (intermittent), Claude Code, and Codex CLI take turns on a free topic or vague idea. Human-orchestrated v1 (one turn at a time, no autonomous looping); peer turns run through the `codex-exec`/`claude-exec` bridges; turn legality lives in a machine-readable header managed by `scripts/meeting.sh`. The collaborative sibling of `/brainstorm` (solo divergence) and `/sdd debate` (two-role spec review). Decision-grade `/meeting` + `/sdd debate` run the spec-149 anti-confirmation-bias protocol (blind commit/reveal opening, claim/evidence convergence gate, minority report) via `meeting.sh`. Git-tracked, project-local transcripts under `.agent0/meetings/` (not propagated to consumers). See `.agent0/context/rules/meeting.md`.

## Squad

`/squad` (spec 150) is the **autonomous, symmetric, ping-pong multi-agent build loop**: two heterogeneous runtimes (Claude Code ↔ Codex CLI) implement one already-`/sdd plan`-ned spec together without a human pumping each turn, until an **externally-verified done-condition** (the `docs/specs/NNN/squad.json` gate: tests/build/validator green) is met — then the human approves and triggers production. **Agent agreement only proposes done; the external gate is the only closer** (spec 149 is the hard predecessor). Bounded (`max_rounds`/`max_repair_attempts` → `aborted_budget`/`aborted_repairs`), turn-locked single-writer (out-of-turn → `aborted_conflict`; forbidden path → `aborted_policy`), human-at-milestone-gates, agents-prepare-prod / human-triggers-prod. State machine `.agent0/skills/squad/scripts/squad.sh`; the runtime drives the pump loop. The autonomous-loop demand spec 138 was gated on, realized as a build loop. See `.agent0/context/rules/squad.md`.

## Routines

`.agent0/routines/<slug>.md` git-tracks recurring project work; an opt-in leader machine's cron enqueues each run for the next interactive session to dispatch via `/routine run <slug>`. See `.agent0/context/rules/routines.md`.

## Artifact size cap

Artifact size is not a scope/quality signal — scope and quality are judged by the `/product` quality judge. The only size mechanism is a uniform 200 KB catastrophe cap (a dumb token-runaway circuit-breaker) plus the retained per-step `min_size` anti-stub floors; trim-loop and re-emit-at-smaller-scope stay forbidden. See `.agent0/context/rules/artifact-budgets.md`.

## Compact Instructions

When summarizing this conversation for context compaction, prioritize keeping:

- The user's most recent intent and the *why* behind in-flight work (not just the *what*)
- Decisions made and rejected alternatives, with reasoning
- Open questions, blockers, and known gotchas hit during the session
- File paths and identifiers that anchor the work (so subsequent searches stay grounded)

Safe to compress:

- Verbatim tool output (file contents, command output) — re-read on demand
- Resolved sub-tasks where the outcome is already in `git log` or the code
- Exploratory tangents that didn't influence the final direction

<!-- AGENT0:END -->
