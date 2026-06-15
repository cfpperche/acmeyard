# Spec-driven development

Non-trivial work in this repo is **spec-driven**: write the intent before the code. The discipline catches half-baked thinking on cheap markdown instead of expensive diffs, and gives the next session (human or AI) a contract to verify against.

## When SDD applies

SDD is owed when, **before editing**, any one of these questions lacks a short answer already determined by existing convention:

1. **What observable behavior or contract changes?** _(nothing visible outside this file → trivial)_
2. **Who outside this local file/module depends on it?** _(callers, another service, a consumer, a public route, persisted data)_
3. **How will it be proven?**
4. **If it is wrong, how is it reverted or migrated?** _(migrations, auth, billing, permissions, persisted data, feature flags rarely have a trivial answer here)_
5. **Which approach was chosen among plausible alternatives?** _(no real choice → trivial)_

If every answer is trivial, already-determined, or not-applicable → **skip SDD**, go straight to the edit. If even one needs explanatory writing → **write a spec** before the code.

**Breadth (file count) is not a trigger.** It is evidence only when it crosses independent boundaries — `API + client + persistence` crosses; `component + hook + test + stylesheet` does not. A wide-but-trivial change (a mechanical rename across many files, an obvious-cause bugfix touching tests and docs) skips SDD; a change crossing a contract or ownership boundary earns it even when the diff is small.

## When to skip

Go straight to the edit when the change is mechanically clear, locally bounded, and has an obvious proof path — **even if several files change**:

- Typos, formatting, lint fixes, dead-code cleanup, dependency bumps without behavior or contract change
- Mechanical renames or field propagation where the source of truth is known and no compatibility/rollout decision is involved — file count is irrelevant
- Obvious-cause bug fixes with a localized behavioral expectation, even when tests, fixtures, or docs also change
- Small UI layout / copy / style / component tweaks that change no flow, state semantics, permission, persisted data, or public contract
- Editing existing specs / docs / configs / tests to reflect already-decided behavior
- Throwaway exploration in a scratch branch

**Skipping SDD never waives proof.** If UI surfaces changed, the UI-acceptance obligation still holds (see `.agent0/context/rules/ui-acceptance.md`) — the proof is a **green project UI test** covering the changed surface, recorded somewhere durable: the PR body, the CI/test output, or the handoff. Use whichever fits the project; do not skip the proof just because there is no spec.

When in doubt, don't ask "how many files?" — ask **which of the five questions a spec would answer**. If the answer is none, skip.

## The artifacts

Specs live under `docs/specs/NNN-<slug>/` where `NNN` is zero-padded sequential (001, 002, …). Each spec has up to five files — the first three are the canonical contract, `notes.md` is in-flight memory, `debate.md` is an opt-in cross-model review:

- **`spec.md`** — the *what* and *why*. Intent, acceptance criteria as scenarios or a checklist (see § *Acceptance scenarios* below), non-goals, open questions. This is the contract — hand it to a stakeholder or paste it into the PR body. The `**Status:**` line near the top declares lifecycle as a **single bare enum value**: `draft` (not started), `in-progress` (work begun), `shipped` (acceptance criteria satisfied), `shipped-partial` (delivered with documented residual scope — name it in `**Closure:**`), `superseded` (replaced by a later spec, slug named inline — e.g. `superseded by 0NN-<slug>`), `abandoned` (killed without replacement; record why in `**Closure:**`), `deferred` (parked indefinitely). Keep `**Status:**` mechanically parseable — do **not** append dates, commit hashes, test counts, or rationale to it; that closure evidence belongs on an optional adjacent `**Closure:**` line (e.g. `**Closure:** 2026-06-08 — shipped at <commit>; tests 8/8; residual: none`). A spec is a **historical decision record**, not a living contract: after ship it does not re-verify against the code unless it opts into a `**Verify:**` command (see `.agent0/context/rules/spec-verify.md`). An optional `**Type:**` line adjacent to `**Status:**` declares the spec's role — omitted (default) for feature/refinement specs that ship code; `umbrella` for aggregators that track closure of multiple child specs without shipping code themselves (acceptance is the closure of every row in a gap matrix, not a code delta). An optional `**UI impact:** none|ui` line declares whether the spec produces UI (default `none`); when `ui`, the spec owes a green project UI test covering the changed surface and drives the `ui-runner-advisory` — see `.agent0/context/rules/ui-acceptance.md`. (The legacy tiers `render|interaction|flow` are collapsed to `ui`.) Expansion to other values (`bugfix` / `refactor` / `research`) is deferred until 3+ specs demand the distinction (rule-of-three demand-test).
- **`plan.md`** — the *how*. Approach, files to touch, alternatives considered and rejected (with reasoning), risks and unknowns. This is the engineering judgment.
- **`tasks.md`** — the *do*. Numbered checklist of concrete execution steps. This is what Claude (or you) works through one at a time, checking off as it goes.
- **`notes.md`** — the *in-flight design memory* (optional in v1). Decisions, deviations, tradeoffs, and open questions surfaced **while building** that weren't pre-empted by `spec.md` or `plan.md`. Append-only by convention. Four canonical sections (`Design decisions` / `Deviations` / `Tradeoffs` / `Open questions`) function as a routing rubric; sections may stay empty. Entry shape: `### YYYY-MM-DD — <author> — <one-line title>` followed by free-prose body, where `<author>` is `parent` or the `subagent_type` of the delegated worker. Distinct from `spec.md` § *Open questions* (pre-flight, set before implementation) and from `.agent0/HANDOFF.md` (cross-session WIP, overwritten each handoff). Append entries when a non-trivial decision wasn't pre-empted by spec/plan; do not log every micro-step. Sub-agent integration via `DELIVERABLE` — see `.agent0/context/rules/delegation.md` § *The 5-field handoff*.
- **`debate.md`** — the *cross-model review* (opt-in). A structured transcript of a debate between the live Claude session and **another tool-calling CLI agent** (separate session — Codex CLI, Cursor, Aider, etc., each porting its own `/sdd debate` equivalent). Both agents read and write `debate.md` directly; the human alternates which agent is active and decides when the debate ends by explicitly asking for synthesis. No copy-paste, no broker process. The artifact IS the audit trail — no separate state file. Lives alongside the spec, git-tracked. Scaffolded and progressed by `/sdd debate` (see § *Workflow* step 1.5). A `/sdd debate`, when run, is **always decision-grade** — this is SDD policy and lives here: a debate MUST run the spec-149 anti-confirmation-bias flow (blind commit/reveal Round 1 to de-anchor the reviewer, claim/evidence convergence gate where `assertion-only` ⇒ unresolved, preserved minority report). `.agent0/context/rules/meeting.md` § De-biased deliberation owns the *mechanics* of that tier (the shared `meeting.sh` commit/reveal/ledger commands); this rule owns the *mandate* that debate always uses it. The legacy position-first Round 1 is a **degraded fallback only when an attempted `meeting.sh` command actually fails** (binary missing, no `sha256` tool, corrupted state) — never a discretionary lighter mode you may simply choose. A degraded debate emits a `debate-degraded:` marker, its synthesis is marked not full-confidence, and it **cannot be cited as the decision-grade convergence gate** that downstream automation (`/squad`) relies on. The file is absent on specs where no debate was held; its absence carries no judgment.

Specs are **git-tracked** — they are the project's design memory. Don't gitignore them. Update them when the plan shifts; the file history *is* the audit trail.

## Workflow

0. **Refine** *(optional)* — `/sdd refine` runs a discovery interview that turns a vague idea into a filled `spec.md`. Opt-in, and especially suited to the "vague request" trigger in § *When SDD applies* — when the *what* itself is unclear, refine before you scaffold. Skip it when the intent is already sharp; go straight to step 1.
1. **Spec** — `/sdd new <slug>` scaffolds the four standard files. Fill `spec.md` first, alone (or let step 0 fill it). Don't plan how until you've nailed what.
1.5. **Debate** *(optional)* — `/sdd debate` runs a cross-model review of `spec.md` between this Claude session and another tool-calling CLI agent in a separate session (Codex CLI, Cursor, etc.), both reading/writing `debate.md` directly. Human alternates active agent + decides when to ask for synthesis. Opt-in, suited to high-leverage specs (schema, public API, security, anything where ambiguity is expensive). Synthesis proposes spec edits; user confirms before they apply. Skip on mechanical specs where a single-model spec is good enough — the cost of running two agent sessions isn't worth it. Skip on low-stakes refactors. See `.agent0/skills/sdd/SKILL.md` § Subcommand: `debate` for the protocol.
2. **Plan** — `/sdd plan` drafts `plan.md` from `spec.md`. Review and edit. Stop here if assumptions need user confirmation.
3. **Tasks** — `/sdd tasks` drafts `tasks.md` from `plan.md`. Each task should be small enough that completing it is unambiguous.
4. **Implement** — work `tasks.md` top-to-bottom. Check off as you go. If a task reveals the plan is wrong, update `plan.md` *before* continuing.
5. **Close** — when the spec is delivered, the spec dir stays — it's the historical record. Reference it from the commit / PR.

## Acceptance scenarios

The acceptance section of `spec.md` should describe **observable behavior** in Given/When/Then scenarios. A scenario is a contract a verifier (human or sub-agent) can mirror directly into `tasks.md`'s verification steps.

### Canonical shape — nested sub-bullets

- [ ] **Scenario: <short title>**
  - **Given** <precondition: state that must hold>
  - **When** <action that triggers the behavior>
  - **Then** <observable outcome: what becomes true / visible>

### Compact shape — inline prose

For short scenarios that fit on one line:

- [ ] **Scenario: <title>** — **Given** <precondition>; **When** <action>; **Then** <outcome>

Use the nested shape by default; switch to inline only when the scenario is genuinely one-line.

### Plain bullets — for static-fact criteria

Not every criterion is a behavior. Existence checks, executable bits, JSON parses, file paths — these are static facts. Use a plain checkbox bullet:

- [ ] `<concrete static fact, e.g. .claude/hooks/foo.sh exists and is executable>`

Mixing scenario bullets with plain bullets in the same `## Acceptance criteria` is expected and correct. Do not force a static fact into Given/When/Then; do not write a behavior as a flat bullet.

### Why this shape

- A scenario is **executable in prose**: a sub-agent dispatched (via the delegation gate) with a 5-field brief whose DELIVERABLE references "scenario N from `docs/specs/NNN-<slug>/spec.md`" can construct the verification without follow-up clarification.
- The Given/When/Then split prevents the common failure mode where an acceptance bullet describes *what* without *when* — the verifier then has to infer the precondition and trigger from plan.md or conversation.
- Tasks.md verification steps map 1:1 from scenarios: each scenario becomes one task that asserts the Then under the Given/When.

### What this does NOT introduce

This is a writing discipline. There is no Cucumber, no Gherkin parser, no test-runner integration, no hook that validates `spec.md` shape. Scenarios are prose; their value is clarity for the next reader (often a sub-agent), not machine consumption. The earliest specs keep their flat-checklist shape — `git log` is the audit trail, not a rewrite.

### Skill-level sibling

Skills with ≥4 step headers carry an analogous discipline at the SKILL.md body level — `## Eval Scenarios` with **Input / Expected / Failure indicators** triples per scenario. Same contract-not-promise filosofia, different unit of work (skill body, not spec body). See `.claude/skills/skill/references/skill-rubric.md` § *Eval scenarios* for the writing convention and `bash .agent0/skills/skill/scripts/check-rubric.sh <slug>` (invoked via `/skill audit`) for the non-blocking advisory.

## Relationship to other rules

- **`research-before-proposing.md`** — research happens *during* spec phase, before `plan.md` is locked. Cite sources in the spec or plan.
- **`session-handoff.md`** — if a spec is mid-flight at end of session, mention the active spec dir in `.agent0/HANDOFF.md` so the next session resumes from `tasks.md`.

## Escalation path

For larger projects (multi-week features, multiple contributors), this convention-light approach has limits. Lightest opt-in upgrade: [OpenSpec](https://openspec.dev/) — `npm i -g @fission-ai/openspec && openspec init` adds delta-spec tracking (`ADDED` / `MODIFIED` / `REMOVED`) and proposal review on top of plain markdown. Doesn't conflict with `docs/specs/`; just adds an `openspec/` tree alongside.

Heavier tools (spec-kit, BMAD) are an option but bring Python/multi-agent overhead. Reach for them only if the project actually needs them.
