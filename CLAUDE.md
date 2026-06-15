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

## Memory

Factual project knowledge lives in `.agent0/memory/<topic>.md`; the trigger-read index is `.agent0/memory/MEMORY.md`. Content is git-tracked for this project, but not shipped to consumers.
Read the index when work touches project architecture, first-party capacities, `.agent0/context/rules/`, `.agent0/hooks/`, `.claude/skills/`, `.agent0/tools/sync-harness.sh`, `.agent0/context/rules/runtime-capabilities.md`, or `.agent0/memory/`.
Follow only relevant entries; ordinary reads do not mutate memory.
Claude uses `.claude/settings.json` hooks. Codex uses tracked `.codex/hooks.json` hooks after the project and changed hook definitions are trusted.
Do not raw-edit `.agent0/memory/MEMORY.md`; edit entries and let projection regenerate it.
Hook-disabled memory edits must end with `bash .agent0/tools/memory-maintain.sh finalize <entry-path>`.
Without hooks, stale-memory readout is `bash .agent0/tools/memory-query.sh decay --readout`.
See `.agent0/context/rules/memory-placement.md` § Multi-runtime usage.

<!-- Capability index (one-line discovery form). Detail for each lives in its rule under .agent0/context/rules/ — read the rule before relying on a capability. Keep each line: command/tool — what it does (keywords) — distinction vs neighbor → rule. -->

## Vuln audit

`/vuln-audit` (+ `.agent0/tools/vuln-audit.sh`) — scan INSTALLED dependencies for known CVEs/advisories (osv-scanner, stack-aware, on-demand); reports + proposes upgrades, never auto-fixes or gates install/commit. See `.agent0/context/rules/vuln-audit.md`.

## MCP recipes

External-MCP server blocks (Playwright, Chrome DevTools, DBHub, Laravel Boost, Next.js DevTools, fal.ai) ship as copy-paste templates only — `.mcp.json.example` (Claude Code) / `.codex/config.toml.example` (Codex), `enabled=false` by default, env-var indirection for secrets. Consult each MCP's upstream README to activate.

## Image generation

`/image` — AI image generation via fal.ai (draft mockups, brand-text, brand-photo/hero), mandatory `--tier`, cost printed before each call. NOT technical diagrams → `/diagram`; NOT motion → `/video`. Needs `FAL_KEY`. See `.agent0/context/rules/image-gen.md`.

## Video generation

`/video` — produce a video, required `--mode code` (deterministic HTML→MP4, free, git-tracked source) or `generative` (paid fal, async, hard `--confirm-cost-usd` gate). NOT a still image → `/image`; not editing recorded footage. See `.agent0/context/rules/video-gen.md`.

## Transcribe

`/transcribe` (+ `.agent0/tools/transcribe.sh`) — local-first speech-to-text: an audio OR video file → transcript (whisper.cpp; content never leaves the machine). NOT text-to-speech → `/audio`. See `.agent0/context/rules/transcribe.md`.

## Audio

`/audio` (+ `.agent0/tools/audio.sh`) — text-to-speech: text → spoken audio/voiceover, local-first/free (Kokoro/Piper), optional paid `--remote` (ElevenLabs). NOT music/SFX → `/sound`; NOT speech-to-text → `/transcribe`. See `.agent0/context/rules/audio.md`.

## Sound

`/sound` (+ `.agent0/tools/sound.sh`) — generate music + sound effects (`--kind music|sfx`), paid-only (the `/image brand` analog), cost-gated, taste-judged. NOT spoken voice → `/audio`; NOT transcription → `/transcribe`. See `.agent0/context/rules/sound.md`.

## Diagram

`/diagram` (+ `.agent0/tools/diagram.sh`) — deterministic technical diagrams (architecture/flowchart/sequence/ER/class/state) from Mermaid → tracked SVG/PNG/PDF, local/free (npx `mmdc` + system Chrome; degrades to validation-only). NOT organic imagery → `/image`; NOT motion → `/video`; NOT runnable UI design → `/frontend-designer`. See `.agent0/context/rules/diagram.md`.

## Capacity kit

`.agent0/tools/lib/capacity.sh` (shared kernel the audio/sound/transcribe/diagram tools `source`) + `.agent0/tools/lib/paid-media.sh` (paid sub-kit for sound, `audio --remote`, video, image) — sourced plumbing helpers behind the capacity tools, not a framework; propagates via the `.agent0/tools/lib|*.sh` sync glob. See `.agent0/context/rules/capacity-kit.md`.

## Harness sync

`.agent0/tools/sync-harness.sh` brings a consumer project's harness up to date with Agent0 via 3-way baseline reconciliation against `.agent0/harness-sync-baseline.json` — stale files auto-update, consumer-customized files refuse without `--force`, never touches product code. See `.agent0/context/rules/harness-sync.md`.

## Lint validator

The post-edit validator runs the project's idiomatic linter — Biome (JS/TS), Ruff (Python), Pint + PHPStan/Larastan (PHP) — when the manifest declares it; missing-but-declared emits a non-blocking `lint-advisory:`. See `.agent0/context/rules/lint-validator.md`.

## Typecheck advisory

The validator runs a typecheck step only when the project declares the primitive (a `tsconfig.json`, or a `typecheck` script in `package.json`); otherwise it emits `typecheck-advisory:` and skips. See `.agent0/context/rules/typecheck-advisory.md`.

## Spec verify advisory

`/sdd` specs opt in to mechanical re-verification by declaring a `**Verify:** \`<cmd>\`` line in `tasks.md`; `.agent0/tools/spec-verify.sh <spec-dir>` runs it from the repo root and records pass/fail to `notes.md`; the validator emits a non-blocking `spec-verify-advisory:` when a **shipped** spec that declares a verify command has no passing record. Opt-in, markdown+shell only. See `.agent0/context/rules/spec-verify.md`.

## Spec close advisory

`.agent0/tools/sdd-close.sh [<spec-dir>]` is a read-only auditor that checks a **shipped** spec's artifacts against its declared status — unchecked tasks/acceptance boxes, surviving `{{placeholders}}`, missing `**Closure:**`. The validator emits a non-blocking `sdd-close-advisory:` **opt-in via the `**Closure:**` line** (a spec that formally closed but whose boxes/placeholders contradict it); specs without a closure line are never nagged, so the legacy corpus stays silent. Complements spec-verify (artifacts vs command); never auto-fixes. See `.agent0/context/rules/sdd-close.md`.

## Context retrieval

`.agent0/tools/context-retrieve.sh search --query "<text>"` — deterministic local retrieval across context rules, memory projection/metadata, specs, and handoff; `context-inject.sh` uses it as a bounded lane after deterministic rule selection (snippets are pointers, no embeddings/vector DB in v1). See `.agent0/context/rules/context-retrieval.md`.

## Status & doctor

`/status` (+ `.agent0/tools/status.sh`) — untruncated live harness-state cockpit (handoff, reminders, routines, decay, git state, suggested next commands), read-only. `.agent0/tools/doctor.sh` reports harness health (files/hooks/binaries/`core.hooksPath`), never fixes. See `.agent0/context/rules/agent0-status.md`.

## Browser primitive

`agent-browser` (+ `.agent0/tools/agent-browser.sh`) — the primary, runtime-neutral agent browser primitive (eyes + hands + observe via shell); fail-closed when binary/Chrome absent (no MCP fallback, spec 153). Attempt-before-handoff: drive browser work yourself or prove an observed blocker before delegating to a human. See `.agent0/context/rules/browser-primitive.md`.

## Browser auth

On an auth-gated URL with no saved state the agent emits `BROWSER_LOGIN_REQUIRED: <host>`; the human runs `bash .agent0/tools/browser-login.sh <host>` and logs in, then the agent attaches over CDP via `agent-browser.sh adopt <host>` and reuses saved state headless. See `.agent0/context/rules/browser-auth.md`.

## UI acceptance

When a spec/task produces UI, "done" is proven by driving the UI, not static review — and the proof is **a green project UI test** (the stack's e2e/runner) covering the changed surface, not a frozen browser bundle (the visual contract is retired — spec 206 supersedes 155). A `**UI impact:** none|ui` declaration is the forcing function. When a UI surface changes but the project declares no UI test runner, the validator emits a non-blocking `ui-runner-advisory:` to provision one (`agent-browser` stays as the dev/inspection primitive only). See `.agent0/context/rules/ui-acceptance.md`.

## Skill compliance

`/skill` — meta-skill that scaffolds, audits, ports, and validates first-party `.claude/skills/*/SKILL.md` against the agentskills.io frontmatter spec, with three declared portability tiers. See `.claude/skills/skill/`.

## Product skill

`/product` — foundation generator + design partner for the product lifecycle (idea → v1 → vN): a multi-step pipeline producing planning artifacts + a visual contract that hands off to SDD; does not generate a runnable app. NOT a real runnable frontend → `/frontend-designer`. See `.claude/skills/product/`.

## Frontend designer

`/frontend-designer` — build-time craft loop that designs or refines a *real, runnable* frontend with taste (`create`/`refine`/`explore`); researches references first, reuses the project's design system, proves output via a green project UI test covering the surface. NOT planning artifacts → `/product`. See `.agent0/context/rules/frontend-designer.md`.

## Meeting

`/meeting` — multi-party, multi-model deliberation (human + Claude Code + Codex CLI take turns on a free topic), human-orchestrated, peer turns via the `codex-exec`/`claude-exec` bridges; decision-grade runs the spec-149 anti-confirmation-bias protocol. NOT solo ideation → `/brainstorm`; NOT spec review → `/sdd debate`. See `.agent0/context/rules/meeting.md`.

## Squad

`/squad` — autonomous, symmetric two-runtime (Claude Code ↔ Codex CLI) ping-pong build loop on an already-`/sdd plan`-ned spec until an externally-verified done-gate (`docs/specs/NNN/squad.json`: tests/build/validator green); bounded, turn-locked single-writer, human-at-milestone-gates. See `.agent0/context/rules/squad.md`.

## Routines

`/routine` — git-tracked recurring project work in `.agent0/routines/<slug>.md`; an opt-in leader machine's cron enqueues each run for the next interactive session to dispatch via `/routine run <slug>`. See `.agent0/context/rules/routines.md`.

## Artifact size cap

Artifact size is not a scope/quality signal — the only size mechanism is a uniform 200 KB catastrophe cap (a dumb token-runaway circuit-breaker) plus the retained per-step `min_size` anti-stub floors; trim-loop and re-emit-at-smaller-scope stay forbidden. See `.agent0/context/rules/artifact-budgets.md`.

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
