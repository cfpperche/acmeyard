---
paths:
  - ".claude/tools/sync-harness.sh"
  - "docs/specs/016-*/**"
---

# Harness sync

A one-way sync tool (`.claude/tools/sync-harness.sh <fork-path>`) that brings a fork's harness state up to date with this Agent0 repo. Hooks, rules, tools, validators, skills, tests, `.mcp.json.example` plus structured merges of `.claude/settings.json` and `CLAUDE.md`. Conservative by design: `--check` is the default (read-only), customized files are detected via hash-compare and refused without `--force`, product code (`src/`, fork's `tests/`, package manifests, `.mcp.json`) is never touched. Spec: `docs/specs/016-harness-sync/`.

## What fires

Nothing automatically. The sync runs only when the developer invokes it explicitly from the Agent0 repo:

```bash
# Read-only drift survey (default)
bash .claude/tools/sync-harness.sh --check ~/some-fork

# Apply changes
bash .claude/tools/sync-harness.sh --apply ~/some-fork

# Dry-run (apply-shaped output, no writes)
bash .claude/tools/sync-harness.sh --apply --dry-run ~/some-fork

# Force-overwrite fork customizations
bash .claude/tools/sync-harness.sh --apply --force ~/some-fork
```

When invoked from a fork (not Agent0 itself), the Agent0 source path must be specified:

```bash
bash sync-harness.sh --agent0-path=/home/goat/Agent0 --apply ~/some-fork
# OR
AGENT0_HARNESS_PATH=/home/goat/Agent0 bash sync-harness.sh --apply ~/some-fork
```

The tool refuses to guess the source path — there is no auto-detection. Refusal exits with code 2 and a usage hint naming both `--agent0-path` and `AGENT0_HARNESS_PATH`.

## Modes

| Mode | Reads | Writes | Exit policy |
| --- | --- | --- | --- |
| `--check` (default) | Agent0 + fork | nothing | 0 = no drift, 1 = drift detected |
| `--apply` | Agent0 + fork | fork | 0 = clean apply, 1 = customizations refused |
| `--apply --dry-run` | Agent0 + fork | nothing | 0 always (decisions only) |
| `--apply --force` | Agent0 + fork | fork (incl. customized) | 0 = clean, customizations overwritten with warning |

## Customization detection

Hash-compare. For each file in scope:

1. Compute `sha256sum` of the Agent0 version and the fork version.
2. If fork's version is **missing** → copy (no customization check; treated as new file).
3. If hashes **match** → up-to-date (no-op).
4. If hashes **differ** AND fork's file exists → **customized**. In `--apply` (no `--force`): refuse with `!! customized <path>` on stderr; in `--check`: same line on stdout, marked as drift; in `--apply --force`: overwrite with `! overwritten <path>` warning.

No marker file in the fork tracks "this came from Agent0" — hash-compare is the single source of truth. If a fork ran a formatter (`prettier`, `shfmt`) over a hook script, the resulting whitespace-only diff is treated as customization (false-positive). Fix: revert the formatter pass, or use `--force` consciously after reviewing the diff.

## settings.json merge strategy

`.claude/settings.json` is structurally merged via `jq`, not hash-compared. Algorithm:

1. Read both files as JSON.
2. For each top-level `hooks.<event>` array (`PreToolUse`, `PostToolUse`, `SessionStart`, `Stop`, `PreCompact`):
   - Concatenate Agent0's entries and fork's entries.
   - `unique_by(.matcher + "|" + (.hooks[].command | join("##")))` — dedup tuple is `(matcher, ordered list of inner commands)`.
3. Write the merged JSON atomically (`mktemp + mv`).

Result: fork-only hook entries (e.g. a fork-specific custom hook) are preserved; Agent0 entries already in fork are not duplicated; new Agent0 entries are appended. Order within an event array is "fork's entries first, Agent0's appended" after dedup — non-binding since hooks run independently.

**Limitation:** when Agent0 renames a hook (e.g. `supply-chain-scan.sh` → `supply-chain-block.sh`), the dedup key changes, so the old entry stays alongside the new one in the fork. The fork's `git diff` post-sync surfaces both; the developer prunes manually. Auto-prune deferred to v2 pending real evidence of this hurting.

## .gitignore merge strategy

`.gitignore` is **additively merged**, not hash-compared. Agent0's `.gitignore` carries harness-runtime entries (`.claude/.runtime-state/`, `.claude/secrets-audit.jsonl`, `.claude/delegation-audit.jsonl`, `.claude/.session-state/`, etc.) that MUST exist in every fork for the harness to run cleanly. Forks typically ship stack-canonical `.gitignore` files (Laravel's `/vendor`, Next.js's `/node_modules`, Cargo's `/target`, etc.) that would be lost under naive overwrite. Algorithm:

1. If fork has no `.gitignore` → copy Agent0's verbatim via `process_file` (counted as `copied`, NOT `merged`).
2. Else extract non-comment, non-empty, trimmed lines from both files as the entry set; compute `comm -23` to find Agent0 entries the fork is missing.
3. If no entries missing → `= up to date` (regardless of comment/whitespace drift; entries are the semantic unit).
4. Else: append a marker line `# === Agent0 harness sync — additions ===` (only on first sync — idempotent on re-runs) followed by the missing entries, preserving Agent0's original ordering. Fork-specific entries are never touched.

Result: a Laravel fork's `.gitignore` keeps `/vendor`, `/node_modules`, `.env`, etc. verbatim, AND gets Agent0's `.claude/*.jsonl` / `.claude/.runtime-state/` / etc. appended below the marker. Idempotent: a second `--apply` reports `= up to date`; `comm -23` returns nothing because the additions from the first run are now in the entry set.

**Force-except scope** — `--force-except='.gitignore'` is honored by the merge handler too: the merge is skipped and `!! force-except .gitignore (merge skipped)` is logged, mirroring the canonical example documented under § Escape hatches. The skip is recorded in the `customized-refused` counter, and the exit code reflects refusal as it does for `process_file`-handled files. This preserves the contract that operators who explicitly say "do not touch .gitignore" get that behavior even after the merge primitive landed.

**Comments and orphans** — the marker block contains entries only, not their source-side comment groupings. Fork developers reviewing the post-sync `git diff` will see flat appended entries; if comment grouping matters for readability, they can reorganize after merge. Comment drift in fork's `.gitignore` (e.g., comments rewritten by the fork) is never overwritten — only the entry set is compared.

## CLAUDE.md managed-block merge strategy

Primary strategy (spec 058). The fork's `CLAUDE.md` declares an explicit Agent0-owned region via paired HTML comment markers:

```markdown
# Fork title

## Overview
... fork-authored project narrative ...

## Gotchas
... fork-authored ...

<!-- AGENT0:BEGIN -->

## Spec-driven development
... Agent0 capacity body ...

## Compact Instructions
... Agent0 capacity body ...

<!-- AGENT0:END -->
```

Markers MUST be on their own lines and match exactly: `<!-- AGENT0:BEGIN -->` and `<!-- AGENT0:END -->`. The dispatcher (`merge_claude_md`) inspects the fork's `CLAUDE.md` and routes by 4-state detection:

| State | Trigger | Behavior |
| --- | --- | --- |
| `paired` | exactly one BEGIN, exactly one END, BEGIN before END | Run managed-block merge: extract region from Agent0 source, check body divergence in shared sections, replace fork region wholesale when no divergence (or under `--force`), refuse on divergence (without `--force`). |
| `absent` | no BEGIN, no END | Run legacy heading-set merge (fallback) AND write `.claude/CLAUDE.md.migration-candidate.md` proposing the wrapped layout for operator review. |
| `mismatched` | one of BEGIN/END present, not both | Refuse the file's merge with `!! claude-md: markers mismatched`; increments `customized-refused`. |
| `nested-invalid` | more than one BEGIN or END, or END before BEGIN | Refuse with `!! claude-md: nested or out-of-order markers`; increments `customized-refused`. |

**Region replacement semantics** — on `paired` state, the lines between markers are extracted from Agent0 source and substitute the fork's region wholesale. Project-narrative sections above BEGIN (and any trailing content after END) are preserved verbatim. The marker lines themselves are preserved exactly. This propagates Agent0 ADDs AND REMOVALs symmetrically — a section dropped upstream is gone on the next sync, fixing the legacy heading-set merge's append-only orphan bug (canonical case: `## Prototype skill` orphaning in forks after spec 048 renamed it to `## Product skill`).

**Body divergence guard** — before replacement, the merge inspects each section title in both fork's region and Agent0's region (intersection); if the body of any shared title differs, divergence is detected. Without `--force`, the merge writes `.claude/CLAUDE.md.diverged-region.md` (per-section list + unified diff), refuses with `customized-refused` increment, and exits non-zero in apply mode. With `--force`, the region is overwritten wholesale and `OVERWRITTEN` increments. Heading-only diffs (fork has sections Agent0 doesn't, or vice versa) are NOT divergence — they are the intended target of the wholesale replace, including orphan removal.

**Migration candidate flow** — when the fork has no markers (state `absent`), spec 058's primary mechanism is to propose the wrapped layout via `.claude/CLAUDE.md.migration-candidate.md`. The candidate file has:

1. A leading HTML comment block explaining itself + Agent0 source SHA at generation time
2. Fork preamble (lines before first `## ` heading)
3. Fork's project-only sections (headings NOT in Agent0's region), preserving fork order
4. `<!-- AGENT0:BEGIN -->` marker
5. Agent0's region content, sourced verbatim from Agent0 source
6. `<!-- AGENT0:END -->` marker

The operator reviews the candidate; if it matches intent, they ratify with `mv .claude/CLAUDE.md.migration-candidate.md CLAUDE.md`. Subsequent syncs route via the `paired` state and apply managed-block semantics. There is no `--migrate-claude-md` flag — the operator's `mv` IS the ratification step (deliberate, per spec 058 Open-Q resolution).

**Per-section divergence blocks migration** — candidate generation runs `_check_section_divergence` against Agent0's region first; if the fork rewrote the body of any Agent0-region-titled section, the candidate is NOT written. Instead `.claude/CLAUDE.md.diverged-sections.md` is written listing the diverged titles. Legacy fallback merge still runs (zero disruption — fork keeps its custom body, gets new capacity sections appended). The operator either renames the heading (removing it from the Agent0-managed namespace) or accepts Agent0's body, then re-runs sync.

**Source must be wrapped for candidate generation** — `_generate_migration_candidate` no-ops when Agent0 source itself has no markers. Markers define the "Agent0-managed namespace"; without them, every `## ` in Agent0 source would be treated as Agent0-owned, falsely flagging fork's `## Overview` body customization as divergence. Agent0's own `CLAUDE.md` ships wrapped from spec 058 onward.

**Mode interaction** — `--check` and `--apply --dry-run` both detect drift but write no files; the dispatcher emits the same advisory shape on stderr ("would write candidate" / "would diverge"). Only `--apply` (no dry-run) writes the candidate or diverged-* reports.

**Idempotency** — once the fork is migrated (markers paired, region matches Agent0 source), `--apply` reports `= up to date` and produces zero mutations. `sha256sum` of `CLAUDE.md` is stable across consecutive applies.

## CLAUDE.md heading-set merge strategy (legacy fallback)

Spec 016's original strategy. Active only when the fork's `CLAUDE.md` lacks paired markers (state `absent` in the dispatcher). Heading-set comparison, **not** full-file hash. Fork-authored sections (Overview, Stack, Conventions, Gotchas, etc.) intentionally diverge from Agent0; a full-hash compare would always flag CLAUDE.md as customized and break the workflow. Algorithm:

1. Extract `^## <Title>` lines from Agent0's and fork's CLAUDE.md.
2. Compute the set of headings in Agent0 missing from fork.
3. If none missing → `= up to date` (regardless of body drift).
4. Else: locate the line containing `## Compact Instructions` in fork's CLAUDE.md (the canonical "always last" anchor). Insert the missing sections (full body extracted from Agent0 via awk) immediately before that line.
5. If `## Compact Instructions` is absent in fork: emit `!! claude-md: missing "## Compact Instructions" anchor — appending at EOF` warning, append at EOF. Developer reorganizes manually if EOF placement is wrong.

Fork-authored sections are always preserved verbatim — the sync only writes Agent0-sourced sections that fork is missing. Append-only is the structural limitation that spec 058's managed-block merge supersedes: a section REMOVED from Agent0 stays as an orphan in fork CLAUDE.md until that fork migrates to the wrapped layout.

## Manifest scope

Encoded in three arrays at the top of `sync-harness.sh`:

- **`COPY_CHECK_RECURSIVE`** — `find -type f` under each base: `.claude/skills/`, `.claude/tests/`, `.claude/agents/`. Recursive walks; subdirs preserved.
- **`COPY_CHECK_GLOBS`** — `dir|pattern` pairs, single-level: `.claude/hooks/*.sh`, `.claude/rules/*.md`, `.claude/tools/*.sh`, `.claude/validators/*.sh`.
- **`COPY_CHECK_FILES`** — literal paths: `.mcp.json.example`, `.gitleaks.toml`, `.githooks/pre-commit`, `.claude/memory/.gitkeep`, `.claude/.browser-state/.gitkeep`.
- **Structured merge** (not in COPY_CHECK): `.claude/settings.json`, `CLAUDE.md`, `.gitignore`.

The walk only reads from Agent0 manifest paths. Out-of-scope fork content (`src/`, fork's `tests/` outside `.claude/tests/`, `docs/`, `package.json`, `Cargo.toml`, `pyproject.toml`, `.mcp.json`, `.env*`, `target/`, `node_modules/`, `.venv/`, `dist/`, `build/`) is **implicitly invisible** — no denylist guard fires because nothing in the manifest points at those paths. This means adding a new path to the manifest is the only way to extend scope; the safety floor is the manifest itself.

## Escape hatches

- `--force` — overwrites customized files. Use after reviewing the diff (`diff <fork>/file <agent0>/file`) and confirming the fork's edits are not load-bearing.
- `--force-except=GLOB[,GLOB...]` — comma-separated globs matched against the per-file relative path. Files matching any glob keep their customized-refused outcome even under `--force`. Canonical use: `--force --force-except='.gitignore'` to adopt drift-only Agent0 updates while preserving fork's stack-specific `.gitignore` patterns. Glob semantics are Bash `case` patterns (`*`, `?`, `[abc]`). Anchored against the full relative path from fork root.
- `AGENT0_HARNESS_PATH=<path>` — env-var alternative to `--agent0-path`. Convenient when scripting multiple fork syncs.
- `--dry-run` — combines with `--apply` to emit decision lines without writing. First-pass discovery on a new fork should always be `--check` or `--apply --dry-run`.

There is no `CLAUDE_SKIP_HARNESS_SYNC` env var — the tool is developer-invoked, not hook-triggered, so per-session disable doesn't apply.

## Audit

None. The sync is a one-shot developer-invoked operation; the `git diff` in the fork after a sync IS the audit trail. The fork developer reviews the diff and commits manually — no auto-commit. Same posture as every other harness primitive that mutates fork state.

If forensic queries become a real need ("which forks ran sync, when, against which Agent0 SHA"), add a `.claude/harness-sync.jsonl` audit log in a v2 spec. v1 keeps the surface minimal.

## Gotchas

- **`## Compact Instructions` anchor missing.** The CLAUDE.md merge looks for this line as the insertion point. A fork that has removed or renamed it will trigger the EOF-fallback warning; capacity sections land at EOF, which may not be the right place. Fix: restore the anchor in fork's CLAUDE.md, or reorganize after sync.
- **Whitespace-only customization false-positive.** A fork that ran `shfmt` / `prettier` over a hook script will have hash-mismatch despite semantic equivalence. The sync flags it as customized. Fix: revert the formatter, OR use `--force` consciously after reviewing the diff. The tool does NOT normalize whitespace (would mask real customizations).
- **`settings.json` array growth on hook renames.** When Agent0 renames a hook, both old and new entries land in the fork's settings.json (different dedup keys). The fork developer must prune manually post-sync. The `git diff` makes this visible; auto-prune deferred to v2.
- **Fork-only test files survive.** A fork that added `.claude/tests/<capacity>/12-fork-extra.sh` keeps that file after sync — sync writes but never deletes. Acceptable: the fork's extra tests survive across syncs.
- **`core.hooksPath` activation is NOT automatic.** Sync writes `.githooks/pre-commit` but does NOT run `git config core.hooksPath .githooks` in the fork. Same Lazarus-vector reasoning as in `.claude/rules/secrets-scan.md` § Gotchas — the fork developer activates consciously, post-sync.
- **Concurrent `--apply` from two terminals.** No locking. Second writer overwrites first's output. Unlikely in practice; the operation is a deliberate developer action, not a hot loop.
- **Bash 3.2 / macOS portability.** The script uses `mapfile`-free patterns (`while IFS= read -r ... done < <(...)` instead of `mapfile`) and avoids `declare -A`. Same baseline every other hook in this repo follows.
- **First sync on a long-stale fork produces a large diff.** A fork that skipped specs 008-012 will see ~30+ new files in one apply. Review the diff section-by-section, not as one giant blob: hooks first, rules second, tools third, then settings.json + CLAUDE.md. Commit in one go (`chore(harness-sync): adopt Agent0 specs NNN-MMM`) so the audit trail is clean.
- **No bidirectional sync.** Improvements made in a fork do NOT flow back to Agent0 via this tool. Fork developers PR-review their improvements upstream. The tool is deliberately one-way to keep the dependency graph clean (Agent0 is upstream-of-everything).
- **`settings.json` references files OUTSIDE the manifest cause silent breakage in forks.** Discovered via shrnk-mono dogfood 2026-05-12: `settings.json` `statusLine.command` referenced `.claude/presence/statusline.mjs`, but `.claude/presence/` was missing from `COPY_CHECK_GLOBS`. Forks received the settings.json reference (via structured merge) but not the file → `node` failed silently → no statusline. **Maintainer rule:** when adding any new directory under `.claude/` that ships scripts referenced by hooks/settings, add a matching entry to `COPY_CHECK_RECURSIVE` or `COPY_CHECK_GLOBS`. The audit `git ls-files .claude/ | awk -F/ '{print $1"/"$2}' | sort -u` lists current subdirs; cross-check against the manifest arrays.
- **`.gitignore` template is stack-agnostic — forks MUST uncomment per-stack patterns post-clone.** Agent0's `.gitignore` ships with `# node_modules/`, `# .venv/`, `# target/`, etc. all commented out (template is intentionally stack-agnostic; forks customize per their actual stack). A fork that forgets to uncomment its stack's lines leaves `git ls-files --others --exclude-standard` dumping thousands of paths into validator's TDD warning loop, hanging the post-edit-validate hook for minutes. The validator gained a defensive grep filter (2026-05-12, validators/run.sh) that strips common noise dir prefixes before the per-file loop — but the fork's correct `.gitignore` remains the primary control. Audit any fork's first session: `git -C <fork> ls-files --others --exclude-standard | awk -F/ '{print $1}' | sort | uniq -c | sort -rn | head` should show low counts for `node_modules`/`target`/`.venv`/etc.
