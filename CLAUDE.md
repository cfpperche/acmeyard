# Agent0 — base repository

Starting point for new software projects. Replace the placeholder sections below as the project evolves. Behavior rules for any agent working on this repo live in `./.claude/rules/`.

## Overview

_Brief description of the project and its purpose._

## Stack

_Language, framework, main dependencies._

## Build & test

```bash
# build:
# test:
# lint:
```

## Conventions

_Style, patterns, architectural decisions — what's not obvious from the code._

## Gotchas

_Non-obvious behaviors, known pitfalls, context not captured in code._

## Spec-driven development

Non-trivial work is spec-first: write intent before code under `docs/specs/NNN-<slug>/{spec,plan,tasks,notes}.md`. Specs are dual-consumer design memory — humans read them for review/audit/validation, agents read them to guide execution (acceptance criteria, approach, task order). `.claude/` is reserved for harness configuration (rules, skills, hooks) that the Claude Code runtime consumes to shape its own behavior. The `/sdd` skill scaffolds and progresses these (`/sdd new <slug>`, `/sdd plan`, `/sdd tasks`, `/sdd list`). See `.claude/rules/spec-driven.md` for when to apply and when to skip.

## Delegation

Sub-agent dispatches via the `Agent` tool are gated by `.claude/hooks/delegation-gate.sh`: every call must use the 5-field handoff (TASK / CONTEXT / CONSTRAINTS / DELIVERABLE-or-DONE_WHEN) so the delegated agent has scope, constraints, and a verifiable outcome instead of inventing its own framing. Edits made by delegated sub-agents are then re-validated by `.claude/hooks/post-edit-validate.sh`, which runs the project validator (`.claude/validators/run.sh`, auto-detects bun/pnpm/npm/python/go/rust) and blocks the sub-agent into a fix-then-retry loop on failure (capped by `CLAUDE_DELEGATION_LOOP_BUDGET`, default 5). Parent edits are exempt; the audit log lives at `.claude/delegation-audit.jsonl`. Same `# OVERRIDE: <reason ≥10 chars>` escape as the governance gate. See `.claude/rules/delegation.md`.

## User prompt framing

Spec 035: the user→main-agent boundary mirrors the delegation gate's discipline, but rule-only by construction — the actor being disciplined (the main agent) cannot externally enforce on itself, so no hook ships in v1. On receipt of a non-trivial prompt, the main agent runs a 3-question mental check (TASK / CONTEXT / DONE clear?) and routes by ambiguity count: 0 → act direct; 1 → act with explicit inference ("assumindo X porque…"); 2+ → clarify via `AskUserQuestion` before acting. Skip categories (path + simple verb, explicit command, factual repo question, short continuation, greeting / meta) bypass the check entirely; opinion-shaped prompts route to the 2-3-sentence-recommendation pattern instead of framing; pronouns resolved by the immediately prior turn count as resolved. Same `# OVERRIDE: <reason ≥10 chars>` escape as the other gates. If the dogfood window surfaces ≥3 missed-clarification sessions, a `UserPromptSubmit` hook becomes the next step (per `.claude/memory/feedback_speculative_observability.md`'s rule-of-three demand-test). See `.claude/rules/user-prompt-framing.md`.

## Test-driven development

TDD is a *cultural* discipline reinforced by the validator — not a blocking gate. Production code follows red → green → refactor; tests land in the same diff that introduces the behavior they cover. When a delegated sub-agent edits production files in a project with a detected test stack, the validator appends a non-blocking `warnings` entry that the post-edit hook surfaces to stderr with a `tdd-advisory:` prefix; the agent should add the missing test before declaring done unless the change is genuinely test-exempt (rename, comment, doc, dependency bump). The `# OVERRIDE: tdd-exempt: <reason ≥10 chars>` shape on a brief documents deliberate skips. BDD scenarios from `spec.md` map naturally to test names. See `.claude/rules/tdd.md`.

## Secrets scan

Two layers (spec 007): the native `.githooks/pre-commit` runs gitleaks over the staged diff at git's actual commit moment and is the primary block; the Claude Code preflight `.claude/hooks/secrets-scan.sh` (PreToolUse Bash) gates dangerous command shapes (compound `git add && git commit`, `git commit -a`, `--no-verify`), parses the override marker, and bridges it across via `CLAUDE_SECRETS_OVERRIDE_REASON`. Activation per-fork: `git config core.hooksPath .githooks` after `git init` (manual on purpose — Lazarus vector). Same `# OVERRIDE: <reason ≥10 chars>` escape as the other gates (multi-line form: marker on its own line); `CLAUDE_SKIP_SECRETS_SCAN=1` disables both layers for throwaway sessions; `CLAUDE_SECRETS_ADVISE_ON_EDIT=1` opts into the soft `secrets-advisory:` on sub-agent edits. Both layers fail open when gitleaks is absent. See `.claude/rules/secrets-scan.md`.

## Supply chain

Two-layer capacity (specs 008+009): a `PreToolUse(Bash)` preflight (`.claude/hooks/supply-chain-scan.sh`) **blocks** dep-mutating commands across 10 managers (npm/pnpm/yarn/bun/pip/uv/poetry/pdm/cargo/go) by default with an exit-2 corrective stderr template, and a `PostToolUse(Edit|Write|MultiEdit)` hook (`.claude/hooks/supply-chain-advise.sh`) flags sub-agent edits to manifest/lockfile basenames (`package.json`, `Cargo.toml`, etc.) as advisory-only (basename match has too high an FP rate to block on). A sibling Bash sub-path emits `advisory-bare-install` when a bare lockfile-resolve verb (`{npm,pnpm,bun}.{install,i}`) runs while `package.json` / `pyproject.toml` / `Cargo.toml` / `go.mod` is uncommitted at hook time — closes the parent-edit + bare-install coverage gap surfaced via shrnk-mono spec 013 dogfood. Each Bash match writes a JSONL row to `.claude/supply-chain-audit.jsonl` with `decision` in `{block, block-override, advisory, advisory-override, advisory-bare-install, advisory-bare-install-override, skip-not-install}`. Same `# OVERRIDE: <reason ≥10 chars>` escape (multi-line form); a valid override records `decision: "block-override"` (or `"advisory-bare-install-override"`) and suppresses the block/advisory stderr. `CLAUDE_SUPPLY_CHAIN_BLOCK=0` falls back to spec-008 advisory-only mode; `CLAUDE_SKIP_SUPPLY_CHAIN_SCAN=1` disables both layers for throwaway sessions. See `.claude/rules/supply-chain.md`.

## Runtime introspect

Spec 011: a `PreToolUse(Bash)` mark (`.claude/hooks/runtime-pre-mark.sh`) stamps the start time per `tool_use_id`, and a `PostToolUse(Bash)` capture (`.claude/hooks/runtime-capture.sh`) tokenises the command, matches a strict verifier allowlist (`bun test` / `bun tsc` / `bun run <keyword-script>`, `npm`/`pnpm`/`yarn` test / build / typecheck / lint / run-script, `pytest`, `python -m pytest`, `python -m unittest`), and writes a single snapshot to `.claude/.runtime-state/last-run.json` containing exit code, duration, and 4 KB head + 4 KB tail of stdout/stderr. The agent reads it back with `bash .claude/tools/probe.sh last-run` — closing the edit→verify loop without human ratification or pure static-code reading. `CLAUDE_RUNTIME_INTROSPECT_EXTRA_DETECT="<space-separated keys>"` adds custom runners (e.g. `make-test`). `CLAUDE_SKIP_RUNTIME_INTROSPECT=1` disables both hooks; `CLAUDE_RUNTIME_INTROSPECT_DEBUG=1` opts into stderr diagnostics. No audit log (deliberate non-feature — `last-run.json` is the latest-snapshot truth). See `.claude/rules/runtime-introspect.md`.

## MCP recipes

Spec 012: opt-in `.mcp.json` recipes for four mature external MCPs (Playwright, Chrome DevTools, DBHub, Next.js DevTools) that complement spec 011's local-process probe on the adopt side of the build-vs-adopt split. A `SessionStart` hook (`.claude/hooks/mcp-recipes-hint.sh`) detects the fork's stack via top-level signals (`next.config.*`, `package.json` deps, `schema.prisma`, `DATABASE_URL` in `.env.example`, …) and emits a single `=== mcp-recipes ===` context block listing applicable recipes when ≥1 matches. Spec 015 extended detection to walk depth-1 into common monorepo workspace dirs (default `apps packages services workspaces`) so a fork with `apps/web/next.config.js` + `apps/api/schema.prisma` surfaces the right hints; workspace-detected signals carry a path prefix. Override the default set via `CLAUDE_MCP_RECIPES_WORKSPACE_DIRS` (space-separated; empty string disables walk, restoring spec 012's pre-015 root-only behaviour). The recipes themselves live in `.claude/rules/mcp-recipes.md` (full per-MCP reference with verified install commands + runtime requirements + security pointers) and `.mcp.json.example` at repo root (copy-paste-ready, all four blocks commented out). Pure recommendation — no auto-installs, no audit log, no blocks. `CLAUDE_SKIP_MCP_RECIPES=1` suppresses the hint. See `.claude/rules/mcp-recipes.md`.

## Harness sync

Spec 016: a one-way sync tool (`.claude/tools/sync-harness.sh <fork-path>`) that brings a fork's harness state up to date with this Agent0 repo. Modes: `--check` (default, read-only — exits 1 if drift), `--apply` (write changes), `--dry-run` (apply-shaped output without writes), `--force` (overwrite fork-customized files with `! overwritten` warning), `--force-except=GLOB[,GLOB...]` (comma-separated globs to preserve under `--force` — e.g. `--force --force-except='.gitignore'`). Source path is explicit — `--agent0-path=PATH` or `AGENT0_HARNESS_PATH` env; refuses to guess. Scope: `.claude/hooks/*.sh`, `.claude/rules/*.md`, `.claude/tools/*.sh`, `.claude/validators/*.sh`, `.claude/skills/`, `.claude/tests/`, `.claude/agents/`, plus `.mcp.json.example`, `.gitleaks.toml`, `.githooks/pre-commit`, `.gitignore`. Structured merge for `.claude/settings.json` (jq dedup by matcher+commands) and `CLAUDE.md` (append missing `^## ` capacity sections before `## Compact Instructions` anchor). Customization detected by `sha256sum` compare; refuses without `--force`. NEVER touches `src/`, fork's `tests/` outside `.claude/tests/`, `docs/`, `package.json`, `Cargo.toml`, `pyproject.toml`, `.mcp.json`, `.env*`. No auto-commit — developer reviews `git diff` and commits manually. See `.claude/rules/harness-sync.md`.

## Lint validator

Spec 013: the post-edit validator (`.claude/validators/run.sh`) extends to lint enforcement when the fork's manifest declares the linter idiomatic to the detected stack — Biome (`@biomejs/biome` in `package.json` `devDependencies`/`dependencies`) for JS/TS, Ruff (declared in `pyproject.toml` or `requirements*.txt`) for Python. Three states per stack: (a) **declared + installed** → append `<runner> biome check` (`bunx`/`pnpm exec`/`npx`) or `<py_prefix> -m ruff check .` to the composed pipeline; failure flips `ok=false` and blocks like tsc/clippy already do; (b) **declared + missing** → emit `lint-advisory: <linter> declared in <manifest> but not installed — run \`<install-cmd>\`` to validator stderr (`bun install`/`pnpm install`/`npm install`/`uv sync`/`poetry install`/`pdm install`/`pip install ruff`); does NOT block, does NOT increment delegation loop budget; (c) **not declared** → silent skip. Manifest-as-intent is the single signal — `biome.json`/`[tool.ruff]` are customization, not intent (a fork with config but no dep declaration hits silent-skip). Single-stack v1: first `if/elif` match wins; multi-stack monorepo lint inherits automatically when spec 015 (monorepo-stack-detect) lands. `CLAUDE_VALIDATOR_SKIP_LINT=1` short-circuits the entire extension; `peerDependencies` is not scanned (linters in peerDeps is antipattern). `post-edit-validate.sh` updated to capture validator stderr separately from JSON stdout so advisory lines surface to the agent without polluting `jq` parsing. See `.claude/rules/lint-validator.md`.

## Typecheck advisory

The validator's JS branches detect typecheck primitive availability per fork before composing the pipeline — a strict `manifest-as-intent` posture mirroring the lint extension. For bun/pnpm: `tsconfig.json` exists → `<runner> tsc --noEmit` (direct invocation); else `package.json .scripts.typecheck` exists → `<runner> [run] typecheck`; else omit typecheck step entirely + emit `typecheck-advisory: no tsconfig.json or 'typecheck' script in package.json — typecheck step skipped (add a tsconfig.json or declare \`<runner> typecheck\` to enable)`. The npm path is conservative (script-only — no `npx tsc` fast-path due to resolution surprises). Replaces a pre-fix hard-failure pattern where `<runner> run typecheck` always landed in the pipeline, breaking validators on early-stage forks. Surfaced via shrnk-mono dogfood 2026-05-12 where every sub-agent edit was hard-failing the validator on a fresh fork without typecheck infrastructure. Same advisory propagation channel as `lint-advisory:` and `tdd-advisory:`. See `.claude/rules/typecheck-advisory.md`.

## Memory

Spec 019: factual project knowledge lives under `.claude/memory/<topic>.md` — git-tracked, propagates between Agent0 contributors via PR/clone, but **NOT shipped to forks** (no entry in sync-harness manifest). When starting work that may benefit from prior decisions, gotchas, or platform constraints, read the lazy-read index at `.claude/memory/MEMORY.md` first, then the specific files relevant to the task domain. Memory is **factual reference** (e.g. "Claude Code has 29 hook events", "we chose hash-compare because X"), distinct from `.claude/rules/` (behavioral mandates the agent SHOULD comply with). No SessionStart auto-load — discovery is via this CLAUDE.md instruction plus cross-references from specific rule docs (e.g. `.claude/rules/runtime-introspect.md` points at `.claude/memory/cc-platform-hooks.md`). Routing guidance for new memories lives in `.claude/rules/memory-placement.md` (3-bucket model: CC per-user for preferences, `.claude/memory/` for project knowledge, `.claude/rules/` for behavior).

## Browser auth

Spec 021: when the agent encounters an auth-gated URL (HTTP 401/402/403 or login redirect) and no `.claude/.browser-state/<host>.json` exists for that host, it emits `BROWSER_AUTH_REQUIRED: <host>` to the chat with a one-line pointer to `.claude/rules/mcp-recipes.md` § Authenticated workflow. The human logs in via a headed Playwright MCP session, saves storage state (cookies + localStorage) to `.claude/.browser-state/<host>.json`, and signals done; the agent then reuses that state for headless reads. **Playwright MCP is the default** for routine authenticated access; Chrome DevTools MCP is debug-only (network observation, perf) and is NOT recommended with `--autoConnect` by default. State files live at `.claude/.browser-state/<host>.json` (gitignored, project-local, never propagated by harness sync). As a low-cost special case, `x.com` / `twitter.com` URLs try `https://unrollnow.com/status/<id>` via `WebFetch` before falling back to the `BROWSER_AUTH_REQUIRED: <host>` signal. See `.claude/rules/mcp-recipes.md`.

## Rule load debug

Opt-in observability for CC's native `InstructionsLoaded` hook event. An `InstructionsLoaded` block runs `.claude/hooks/rule-load-debug.sh`, which self-gates on `CLAUDE_RULE_LOAD_DEBUG=1` and otherwise exits silently. When enabled, each CLAUDE.md / `.claude/rules/*.md` load — at `session_start`, `path_glob_match`, `nested_traversal`, `include`, or `compact` — appends one JSONL row to `.claude/.rule-load-debug.jsonl` (gitignored, `flock`-atomic, append-only) capturing `file`, `memory_type`, `load_reason`, `globs` (when path-scoped), `trigger_file` (the file whose access triggered the load), `session_id`. Pure observability — the harness ignores stdout/stderr for this event by design; the audit log + probe is the only signal path. Read back with `bash .claude/tools/probe.sh rule-loads [--json] [--session <id>] [--reason <r>]`. Canonical use: verify path-scoped rules fire on the correct triggers after a frontmatter edit, debug "rule didn't load when expected" symptoms, audit compaction re-load behavior. `CLAUDE_RULE_LOAD_DEBUG` unset or `0` is the default (zero per-load overhead). See `.claude/rules/rule-load-debug.md`.

## Skill compliance

Spec 033: every first-party `.claude/skills/<name>/SKILL.md` must pass the agentskills.io frontmatter spec (Anthropic's open standard, adopted by 40+ runtimes — Hermes Agent, Codex, Cursor, Goose, OpenCode, others — so spec-compliant skills are cross-runtime portable for free). The `/skill` meta-skill handles the lifecycle: `/skill new <slug> [--tier <tier>]` scaffolds a compliant SKILL.md from `.claude/skills/skill/templates/`; `/skill audit [<slug>|--all]` reports per-skill compliance + portability tier; `/skill port <slug>` invokes `scripts/port-frontmatter.sh` to add missing required fields (`name`, `compatibility`, `metadata.agent0-portability-tier`) while preserving body bytes byte-identical; `/skill validate <slug>` runs `scripts/validate.sh` (zero-dep bash; defers to `skills-ref validate` when on PATH per defer-to-canonical pattern). Three portability tiers declared in `metadata.agent0-portability-tier`: `cc-native` (body uses `.claude/`-only paths / CC-specific tools), `agentskills-portable` (universal primitives only — file IO, shell, web), `runtime-agnostic` (also OS-portable). The frozen agentskills.io spec lives at `.claude/skills/skill/references/spec-snapshot.md` (retrieved 2026-05-17); the validator's rule set is in `references/frontmatter-validation-rules.md`; tier definitions and the two locked decisions (the `agent0-` namespace prefix, `argument-hint:` staying top-level) are in `references/portability-tiers.md`. CC-marketplace skills (`init`, `review`, `security-review`, etc.) are surfaced by the CC harness, not by this repo's `.claude/skills/`, and are out of scope for the toolkit.

## Prototype skill

Spec 034 shipped `/prototype` v1 as the agile alternative to the 13-step `mcp-product-pipeline`, but covered only ~25-30% of the pipeline (4 of 13 steps partially, 8 missing entirely) and harboured a render-killing tokens.css import false-positive bug surfaced via the 2026-05-17 dogfood ("skill rejeitada" user feedback). Spec 036 (`prototype-skill-refactor`) reframes v1 as the agile *frontend* to the same 13-step pipeline: same artifacts (concept brief → spec → UX audit → brand → design system → PRD → system design → cost → roadmap → legal → 3 prototype passes), single "standard" depth tier, standalone (13 step templates + OD vendor index bundled at `.claude/skills/prototype/templates/pipeline/` — 1.3 MB, no MCP runtime dep), 4-phase orchestration (Discovery / Identity / Specification / Synthesis) with 3 `AskUserQuestion` gates between phases. New flags: `--out=<path>` (required; drops v1 `/tmp/` hardcode) and `--from-step=NN` (resume after abort). Per-phase parallel dispatch enforced via explicit "N Agent calls in one message" worked example in SKILL.md. Sub-agent models declared per step: Step 01 (concept brief) = `opus`; Steps 02-13 = `sonnet`. Spec 034 stays `shipped` (v1 still routable) until v2 dogfood replay validates end-to-end — premature supersede would break forks pulling mid-refactor. Quarterly REMINDERS item tracks bundled-vs-canonical template drift sync. See `.claude/skills/prototype/references/{pipeline-coverage,state-machine,delegation-briefs,quality-checklist}.md` for v2 design.

## PHP / Laravel

Spec 047: when a fork contains `composer.json` at the project root (canonical), or `artisan` at the root (Laravel-specific signal), seven Agent0 capacities activate PHP-aware behavior — validator picks `vendor/bin/pest` or `vendor/bin/phpunit` based on composer.json declarations; supply-chain blocks `composer require <pkg>` with the same `# OVERRIDE: <reason ≥10 chars>` escape as npm/pip/cargo/go; runtime-introspect captures `vendor/bin/phpunit`, `vendor/bin/pest`, `php artisan test`, `composer test`, and `composer lint` snapshots; TDD recognises `tests/`, `*Test.php`, and `*_test.php`; lint extension runs Laravel Pint and PHPStan/Larastan when declared in `composer.json` `require-dev`; MCP recipes hint suggests `laravel-boost-mcp` + `playwright-mcp` when `artisan` or `laravel/framework` is detected, with the `.mcp.json.example` block ready to uncomment. Detection is fail-loud — a PHP fork that lacks declared linters or test infrastructure will see `lint-advisory:` / `tdd-advisory:` lines on the next turn pointing at the missing piece. Multi-stack JS+PHP monorepos route to the first matching elif (currently JS-first, PHP late); proper multi-stack walking is spec 015 territory. See `.claude/rules/php-laravel-support.md` for the umbrella index linking each capacity's canonical doc.

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

`.claude/COMPACT_NOTES.md` is regenerated by the PreCompact hook with the last 12 turns verbatim — that file is the source of truth for raw signal across the compaction boundary, so the summary itself can stay terse.
