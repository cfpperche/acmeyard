---
paths:
  - ".agent0/context/rules/scope-admission-governance.md"
  - ".agent0/context/rules/agent0-governance-doctrine.md"
  - ".agent0/context/rules/spec-driven.md"
  - "docs/specs/"
---

# Scope admission governance

Use this rule before writing or approving a spec that adds, hardens, or expands a first-party Agent0 capacity. It is the operational form of spec 166's scope-admission doctrine.

The goal is not to slow work down. The goal is to stop Agent0 from accreting mechanisms just because they are plausible.

## When this applies

Apply this rule when a proposal would add or materially change any of:

- first-party hooks, validators, gates, advisories, tools, skills, context rules, sync surfaces, runtime bridges, or capacity kits;
- a new governance lane or taxonomy category;
- a new blocking behavior or a hardening of an advisory/report into a gate;
- consumer-propagated harness surface;
- a product-like interface such as a dashboard, daemon, hosted service, release runner, or operational control plane.

Do not apply it to ordinary consumer product code, small docs fixes, typo fixes, or narrow maintenance inside an already-admitted capacity unless the change expands the capacity's scope.

## Admission outcomes

Every proposal should land in one of five outcomes:

- **Admit** - build a spec now. Evidence exists, scope is bounded, and Agent0 clearly owns or should instrument the surface.
- **Instrument only** - provide prompts, documentation, reports, or evidence helpers, but do not own the consumer lifecycle operation.
- **Harden existing** - upgrade an existing advisory/report/check only after the hardening bar is met.
- **Defer** - record the idea with a concrete reopen trigger, reminder, routine, or spec open question. Do not build yet.
- **Reject** - name the non-goal and stop carrying the idea as pending work.

Avoid "maybe build later" without a trigger. A deferred idea needs a condition that can fire.

## Evidence ladder

Prefer the lightest sufficient evidence:

1. **Explicit founder directive** - enough to explore and spec, but not enough to skip scope boundaries, safety, or validation.
2. **Dogfood failure** - the harness failed in a real Agent0 or consumer workflow.
3. **Rule-of-three demand** - the same class of pain appears at least three times, or across enough distinct contexts that one-off handling is no longer credible.
4. **Named reopen trigger fired** - a prior spec or rule explicitly recorded the condition and the condition now holds.
5. **Consumer propagation pain** - sync, customization, or runtime parity breaks in a consumer in a way the harness should reasonably prevent.
6. **Narrow safety exception** - a single severe security, credential, data-loss, or destructive-operation risk can justify immediate action, but only the smallest fix that addresses the incident.

External industry patterns, one interesting gist, or a model capability trend are not enough by themselves. Capture them in memory, brainstorm, reminder, routine, or meeting notes until they intersect with local evidence.

## Admission brief

For an admitted Agent0 capacity spec, include these answers in `spec.md`, `plan.md`, or `notes.md`:

- **Layer:** continuous-evolution spine, quality/security domain, context/replication substrate, transversal constraint, or scope-admission meta-governance.
- **Boundary:** Agent0 owns, instruments, or ignores the lifecycle surface.
- **Evidence:** founder directive, dogfood failure, rule-of-three, reopen trigger, consumer pain, or narrow safety exception.
- **V1 posture:** rule-only, documentation, report, advisory, rewrite, soft gate, hard gate, tool, or skill.
- **Blast radius:** Agent0-only, shipped to consumers, local-only, paid/remote, credential-class, or runtime-specific.
- **Validation:** what proves the capacity works and what future maintainers should rerun.
- **Non-goals:** adjacent product/platform scope that remains out.

This brief is a writing discipline, not a schema. Do not add a mandatory SDD template section until repeated specs show the manual form is being missed.

## Hardening bar

A new hard gate or an advisory-to-block promotion requires more than "this would be safer." The spec must show:

- deterministic trigger and check;
- low false-positive risk in normal consumer projects;
- clear bypass or override story when blocking is wrong, including audit trail when appropriate;
- bounded consumer blast radius;
- tests for allow, block, malformed input, and bypass cases;
- evidence that advisory/report-only is insufficient;
- the exact command or hook path that proves the behavior.

If these are not true yet, ship advisory/report-only or defer.

## Product-drift boundary

Agent0 can instrument consumer release and operation with evidence, prompts, and checks. It should not own the release, deployment, runtime observability, business workflow, or operational authority of a consumer product.

Product-like surfaces are rejected by default. To move the boundary, a future spec must prove recurring user pain, maintenance ownership, sync implications, runtime support, and why template/governance mechanisms are insufficient.

## Recording deferred work

Use the smallest durable record that matches the trigger:

- **Spec open question** - when the decision belongs to the current spec.
- **`notes.md`** - when implementation revealed a future concern but the current spec should not expand.
- **Reminder** - one-shot revisit tied to a date or condition.
- **Routine** - recurring project work with an idempotent cadence.
- **Memory** - factual project knowledge or external pattern worth retrieving later.
- **Brainstorm/meeting** - unresolved strategy or multi-party deliberation.

Do not leave deferred work only in chat. If it matters, put it somewhere the next session can retrieve.

## Notes

_Consumer-extension surface - append consumer-local bullets here. Sync flags the file as `!! customized` (sha-compare is section-blind), but the conflict region is mechanically this section: take new upstream verbatim, re-add consumer bullets at the end._
