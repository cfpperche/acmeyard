# Vuln audit

`/vuln-audit` (and its engine `.agent0/tools/vuln-audit.sh`) detects **known-vulnerable installed dependencies** in a project, on demand, and surfaces them with enough context to act. It is the positive replacement for a supply-chain block/advise capacity that was removed because it gated `npm install` at the wrong moment — the decision was explicit: **don't limit lib usage at install time; detect vulnerable installed libs and act.** This capacity answers one narrow, high-signal question from the project's lockfiles — "does a dependency I already lock have a published advisory with a fixed version?" — across whatever ecosystems the project actually has (stack-aware), identically under Claude Code and Codex CLI (runtime-neutral). It reports and proposes; it never auto-upgrades and never blocks a commit or an install.


## Trigger surface — on-demand only

The audit runs **only when invoked** — via `/vuln-audit` in Claude Code, or `bash .agent0/tools/vuln-audit.sh` directly (Codex CLI / any runtime / CI). It is deliberately **not** on the `PreToolUse(Bash)` install path, **not** on the `.githooks/pre-commit` path, and **not** scheduled. Gating install is the wrong shape; a commit gate is the same anti-pattern one step later.

**Staleness limitation (honest by design):** a vulnerability published *after* your last run is invisible until you next run it. A recurring cadence is the documented deferred path via the generic `/routine` capacity — point a routine at `bash .agent0/tools/vuln-audit.sh` if you want periodic scans. No v1 code ships for this; see `.agent0/context/rules/routines.md`.

## Engine — osv-scanner-only (v1)

The engine is **osv-scanner** (Google): one static binary, 19+ lockfile ecosystems in a single pass, the OSV database (free/transparent), call-graph FP reduction. It is `osv-scanner`-only in v1 by deliberate decision:

- **Trivy was rejected** — its release infrastructure was supply-chain compromised in March 2026 with vulnerability-DB updates suspended; disqualifying for a security tool.
- **No second-source fallback matrix** (`npm audit` / `pip-audit` / `bun audit`) — it reintroduces divergent severity models, package-identity normalization, duplicate findings, and per-ecosystem remediation semantics. Deferred behind observed demand (rule-of-three).

**Source-completeness caveat (load-bearing).** The capacity reports *"known vulnerabilities found by the selected OSV-backed engine,"* NOT *"all vulnerabilities known anywhere."* Independent scanners overlap only ~60–65%, so a single engine provably misses some advisories another database would catch — a source/DB difference, accepted in v1. Frame a `clean` result accordingly.

## Stack-awareness — the three-bucket coverage contract

Every run emits a coverage report with three explicit buckets, so "stack-aware" never silently degrades to "whatever the engine noticed":

- **`found`** — recognised lockfiles discovered in the tree (via a thin Agent0-side lockfile→ecosystem map; vendor/`node_modules`/`.git` pruned).
- **`covered`** — lockfiles the engine actually parsed (from `results[].source.path`).
- **`skipped/unsupported`** — discovered but not parseable, each with a reason. The canonical case: a legacy binary **`bun.lockb`** (osv-scanner parses only the text `bun.lock`, default since Bun ≥1.2) → reason carries a "regenerate as text `bun.lock` via `bun install`" hint.

A partially-covered project is therefore never reported as a clean one.

## Result status vs process exit code

The tool reports exactly one first-class **result status**, decoupled from the process exit code:

| Status | Meaning |
|---|---|
| `clean` | engine ran, no known-vulnerable deps in its corpus |
| `findings` | engine ran, ≥1 known-vulnerable dep |
| `unavailable` | osv-scanner binary not installed (advisory + install hint) |
| `failed` | engine ran but errored / produced unparseable output |

**The process exit code defaults to `0` for all four statuses** — this is the non-blocking advisory family (`lint-advisory:` / `typecheck-advisory:` / `tdd-advisory:`). An opt-in `--exit-code` maps statuses → non-zero codes for **consumer-owned CI** (`clean`=0, `findings`=1, `unavailable`=2, `failed`=3). `--exit-code` reflects only the selected engine's status (never multi-source assurance) and is never wired into any Agent0 gate. `jq`-absent also fails open (advisory, exit 0).

## Output

- **Human-readable (default)** — status line, coverage summary, skipped lockfiles with reasons, and per-finding records: `[severity] package@version (ecosystem, direct|transitive)`, advisory id + CVE, fixed version (or "no fix published"), and a remediation path (the direct dependency name, or "no direct remediation path known" for transitive-only findings whose path the engine doesn't expose).
- **`--json`** — a deterministic structured document (status + coverage buckets + findings). **Shape-only convenience, not a versioned wire contract** — the field set may evolve and there is no schema-version key, deliberately (same posture as `/sdd list --json`). It exists for tests, multi-runner parity, and agent-generated summaries — *not* a persisted audit log (no JSONL trail ships, per the rule-of-three demand test).
- **`--severity <low|moderate|high|critical>`** — report only findings at or above the floor; default reports all, no floor.

## Remediation discipline — propose, never apply

The capacity names the upgrade target for fixable findings but **does not modify any manifest or lockfile**. No `osv-scanner fix --apply`, no `npm audit fix`, no `bun audit fix`. This is the contract-not-promise discipline (`.agent0/context/rules/delegation.md` § Why DONE_WHEN exists): applying an upgrade is a separate action the human confirms. osv-scanner's own `fix` command is explicitly risky on untrusted projects (it can trigger package-manager script execution), which reinforces the no-auto-fix stance.

## No override marker — nothing to bypass

Unlike the project's gates (delegation, secrets-scan, governance, routines), vuln-audit has **no `# OVERRIDE:` grammar and no skip env-var** — because it never blocks anything. There is no gate to bypass; the only knob is whether you run it. This absence is deliberate, not an omission.

## Non-goals

- Gating install or commit; auto-upgrading dependencies.
- A default second scanner source (incl. native `bun audit` for `bun.lockb`-only projects — those land in `skipped` with a migrate hint instead).
- A self-built reachability / call-graph layer — reachability is surfaced only as a pass-through field when the engine already computes it.
- SBOM generation, container-image scanning, IaC misconfig, license compliance, secret scanning (the last already exists — `secrets-scan`).
- Bundling / auto-installing the engine binary; a standing audit log / dashboard.

## Files

- `.agent0/tools/vuln-audit.sh` — the runtime-neutral engine (detect → invoke osv-scanner → parse → bucket → status → render).
- `.claude/skills/vuln-audit/SKILL.md` — thin Claude Code invocation wrapper.
- `.agent0/tests/vuln-audit/` — 10 scenario tests using a fake-osv stub (offline, deterministic) + `run-all.sh`.

## Cross-references

- `.agent0/context/rules/secrets-scan.md` — sibling security capacity (the gate-shaped one this deliberately is *not*).
- `.agent0/context/rules/tdd.md` § Reading the validator advisory — the `<kind>-advisory:` non-blocking family this mirrors.
- `.agent0/context/rules/routines.md` — the deferred recurring-cadence path.
