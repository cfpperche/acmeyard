---
paths:
  - ".agent0/tools/sdd-close.sh"
  - ".agent0/validators/run.sh"
  - "docs/specs/*/spec.md"
  - "docs/specs/*/tasks.md"
---

# Spec close advisory

A spec that declares `**Status:** shipped` is asserting it is done. **sdd-close** checks that the spec's own artifacts back that assertion. `.agent0/tools/sdd-close.sh` is a read-only auditor that reports, per shipped (or `shipped-partial`) spec, where the artifacts disagree with the declared status; the post-edit validator (`.agent0/validators/run.sh`) emits a non-blocking `sdd-close-advisory:` for specs that have **formally closed** (declare a `**Closure:**` line) but whose artifacts still contradict that closure. It is the static-consistency complement of [spec-verify](spec-verify.md) (spec 177): verify proves the spec's *command* still passes; close proves the spec's *artifacts* agree with its status. It never runs or duplicates `**Verify:**`. Spec 179.

## The four findings

For a shipped / `shipped-partial` spec, sdd-close reports any of:

- **`tasks-unchecked`** — `tasks.md` still has `- [ ]` boxes (the canonical defect: spec 177 shipped with every task box unchecked).
- **`acceptance-unchecked`** — `spec.md`'s `## Acceptance criteria` section still has `- [ ]` boxes (counted only within that section — Open-questions boxes do not count).
- **`placeholders`** — surviving `{{...}}` scaffold placeholders in `spec.md` or `tasks.md`. Inline `` `code` `` spans are stripped first, so a spec that merely *discusses* template syntax (e.g. `` `{{SLUG}}` ``) is not a false positive.
- **`missing-closure`** — no uncommented `**Closure:**` line (see [spec-driven.md](spec-driven.md) § The artifacts for the closure convention).

## The tool (on-demand, full audit)

```
bash .agent0/tools/sdd-close.sh [<spec-dir>] [--json]
```

No argument audits every `docs/specs/*`; one `<spec-dir>` audits just that spec. Output is a human summary by default, a single JSON object with `--json`. Exit `0` (no findings) / `1` (findings) / `64` (usage). It is **read-only** — it never checks a box, writes a closure line, or touches any file. Run it deliberately when closing a spec or auditing the corpus; because invocation is intentional, it reports **everything**, including `missing-closure` across the legacy corpus.

## The advisory (opt-in via `**Closure:**`)

The validator advisory is deliberately **opt-in**, mirroring how spec-verify opts in via `**Verify:**`. It fires **only** for a shipped spec that declares a `**Closure:**` line — i.e. one that has formally closed and is therefore held to the modern consistency bar:

```
sdd-close-advisory: docs/specs/NNN-slug declares **Closure:** but 3 unchecked task(s), surviving placeholders — run bash .agent0/tools/sdd-close.sh docs/specs/NNN-slug
```

Only the three hard findings (`tasks-unchecked`, `acceptance-unchecked`, `placeholders`) drive the advisory; `missing-closure` does **not** — under opt-in, the absence of a closure line *is* the opt-out, so it cannot also be a nag. One aggregated line per spec; emitted to stderr; it never alters the validator's `ok`/exit.

### Why opt-in, not recency (the noise model)

The advisory must not nag the legacy corpus. A rolling recency window was tried and rejected: Agent0 ships ~4 specs/day (a 14-day window still captured ~80 specs), the closure convention is recent (so every pre-convention spec tripped a finding), and git mtime is useless here (Agent0 is a consolidation repo where all specs share one bulk-migration commit date). The `**Closure:**` line is the honest, self-scoping signal — a spec that opts into closure opts into the check; everything else stays silent. On the live corpus this advisory emits **zero** lines until a closed spec actually drifts. This keeps the capability on the right side of the speculative-observability line — surfacing a real, demonstrated defect, not manufacturing nags.

## Opt-out

Set `CLAUDE_VALIDATOR_SKIP_SDD_CLOSE=1` to skip the advisory pass entirely (the on-demand tool is unaffected).

## Gotchas

- A `**Closure:**` line that is still commented out (`<!-- **Closure:** -->`, the template default) does **not** count as opting in — only an uncommented line does.
- The advisory checks the spec at validator time; it does not re-run when you check boxes — re-run the validator (or the tool) to clear it.
- `shipped-partial` specs are checked too; if they legitimately carry residual scope, record it on the `**Closure:**` line and check the boxes that are actually done.

## Consumer extension

This rule and `sdd-close.sh` ship to consumers via `sync-harness`. A consumer that adopts the `**Closure:**` convention automatically gets the consistency check on its own closed specs; a consumer that never declares closure never sees the advisory. Append consumer-local notes below this line.
