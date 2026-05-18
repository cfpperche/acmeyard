# PRD coverage rubric — mapping step 8 user-story IDs to screens

The PRD-coverage matrix in `screen-atlas.md` § PRD Coverage is the load-bearing scorecard that proves the visual contract covers every `US-NN` from step 8 PRD. This page documents the per-US-NN mapping discipline, the coverage-score arithmetic, the deferred-with-reason discipline, and the cross-references that close the trace from "user story declared" → "screen designed" → "engineering builds against".

## The US-NN ID convention (inherited from step 8)

Step 8 PRD establishes the stable, zero-padded sequential ID convention per `08-prd/references/prd-format.md`: `US-01`, `US-02`, ..., `US-29`, `US-30`. The ID is the contract between PRD and downstream consumers — step 13 is the canonical downstream consumer that step 8's convention was designed for.

**ID stability rules** (from step 8 — must hold for step 13's matrix to work):
- New stories appended at the END of step 8's user-stories section. IDs never reshuffle.
- Removed stories keep their ID with strikethrough in step 8. Removed IDs do NOT appear in step 13's matrix.
- Reordered stories keep their original IDs. The ID is the story's identity, not its position.
- Splitting one story into two: the original keeps its ID; the carved-out half gets a new ID. Both appear in step 13's matrix.

**If step 8 PRD does NOT carry stable US-NN IDs** (regression from the spec 026 step-8 port), step 13 cannot produce a coherent coverage matrix. Stop and report to the parent — step 8 needs revision before step 13 fires.

## How to enumerate US-NNs from step 8 PRD

Read `docs/product/08-prd/prd.md` § User Stories. Extract every `**US-NN.**` (note the period — that's the canonical anchor per step-8 prd-format reference). Capture:

1. **The ID** (`US-NN`).
2. **The story summary** (the "As a X, I want Y so that Z" sentence; collapse to a short title for the matrix's `Title (short)` column).
3. **The priority tier** — cross-reference against `## Must Have (P0)` / `## Should Have (P1)` / `## Could Have (P2)` / `## Backlog` tables. A US-NN may appear in BOTH § User Stories AND a Requirements table; the Requirements-table priority is authoritative.
4. **The acceptance source** — cross-reference against `## Acceptance Criteria § US-NN` if step 8 used per-US-NN ACs, otherwise against the Requirements-table AC column.

The enumeration is mechanical — agent reads the PRD, builds the row list. NOT a judgment call.

## Mapping US-NN to screen — the routing discipline

For each US-NN, the agent decides which screen(s) cover it. Three valid routing patterns:

### Pattern 1 — One US-NN → one screen (typical)

```markdown
| US-01 | Sign up via email/Google | P0 | `screens/02-signup.html` | PRD § AC US-01 | covered |
```

The US is fully covered by one screen. The Screen(s) column names the file; the Acceptance Source column cites the PRD section that defines the acceptance.

### Pattern 2 — One US-NN → multiple screens (multi-surface story)

```markdown
| US-07 | Keyboard-first triage flow | P0 | `screens/05-killer-flow.html`, `screens/04-dashboard.html` | PRD § AC US-07; F-12 resolved at screen 05 | covered |
```

The US spans multiple screens (e.g., the triage flow starts at dashboard and culminates at the killer-flow surface). Both screens listed. Acceptance Source may cite per-screen.

### Pattern 3 — Multiple US-NNs → one screen (composite surface)

```markdown
| US-04 | Land in workspace dashboard | P0 | `screens/04-dashboard.html` | PRD § AC US-04 | covered |
| US-06 | See cycle-time aggregate | P1 | `screens/04-dashboard.html` | PRD § AC US-06 | covered |
| US-19 | Bulk-action with confirmation | P0 | `screens/04-dashboard.html`, `screens/05-killer-flow.html` | PRD § AC US-19; F-13 resolved at screen 05 | covered |
```

Multiple US-NNs land on the same screen (typical for the dashboard, which is a composite surface). Each US-NN gets its own row in the matrix; the Screen column may repeat across rows.

## Status values and their semantics

Per US-NN row, the `Status` column carries one of three values:

### `covered`

The US is fully rendered on the screen(s) listed. The screen's HTML demonstrates the acceptance criterion (the keyboard hint is visible, the form field is present, the confirmation modal renders, etc.). Engineering reads the row, opens the screen, sees the design pattern, builds against it.

### `deferred — <reason>`

The US is NOT rendered on any step-13 screen. The deferral has a reason that survives review. Three canonical reason types:

- **Phase-deferred** — the US is scoped out of v1 per step-11 roadmap. Reason: "deferred — Phase 3 per step-11 roadmap § Phase 3" (cite the roadmap section).
- **Founder-deferred** — the US has open questions the founder hasn't resolved. Reason: "deferred — admin-flow needs design partner #2's feedback; surface in atlas § Open Decisions".
- **Dependency-deferred** — the US depends on a system component not yet specified. Reason: "deferred — depends on multi-tenancy schema per step 9 § Open Decisions row 4".

**`deferred` without a reason is the regression mode.** A reader (engineering, designer, founder) opening the atlas needs to know WHY the US is deferred to decide whether to escalate or accept the deferral.

### `partial — <screen carries part>`

The US is partially covered — the screen renders part of the acceptance criterion but NOT the full story. Reason names what's covered + what's missing. Example: "partial — `screens/08-empty-error-consent.html` carries the admin-toggle visible but full role-management surface deferred (US-22 admin-flow needs design partner #2's feedback)".

`partial` is a soft signal — engineering reads it as "the screen exists but the US-NN's full acceptance is not satisfied". Use sparingly; prefer `covered` (when the full story IS covered) OR `deferred` (when nothing is covered).

## The coverage-score arithmetic

The section closes with the `## PRD coverage: X/Y` summary line where:

- **Y** = total US-NN count in step 8 PRD (every row in the matrix, including deferred + partial).
- **X** = count of rows with status `covered`. Partials count as 0.5 (rounded down at the score level).

Examples:
- 10 covered, 2 deferred → `## PRD coverage: 10/12`
- 9 covered, 1 partial, 2 deferred → `## PRD coverage: 9/12` (partial rounds down)
- 12 covered, 0 deferred → `## PRD coverage: 12/12`

The score is a **gate signal for `/sdd new <slug>`**: a P0 US-NN in `deferred` status SHOULD hold the `/sdd` handoff (engineering can't build without the contract); a P1 or P2 in `deferred` is acceptable for v1. The atlas § Overview § "Deciding signal for engineering handoff" one-liner is the literal "hold /sdd if any P0 is uncovered" rule.

## REPORT.md § PRD Coverage cross-reference

The REPORT.md § PRD Coverage section is the engineering-facing summary. Format:

```markdown
## PRD Coverage

**Score: 10/12** (10 covered, 2 deferred)

Per-priority breakdown:
- **P0** (must-haves): 5/5 covered. All gate-critical user-stories rendered.
- **P1** (should-haves): 3/4 covered. US-18 (multi-project view) deferred — Phase 3 per step-11 roadmap.
- **P2** (could-haves): 0/2 covered. US-22 (admin role) deferred — pending design-partner feedback; US-26 (custom keyboard remapping) deferred — post-launch refinement per step 8 § Backlog row B-4.

Deferred US-NN list:
- **US-18** — Multi-project view across workspaces. Deferred to Phase 3 per step-11 roadmap (v2 enterprise tier expansion).
- **US-22** — Admin role management. Deferred — admin-flow needs design partner #2's feedback; surface in screen-atlas § Open Decisions row 4.
```

The REPORT version is the engineering-facing summary; the atlas version is the per-US-NN audit trail. Engineering reads REPORT for the score + per-tier breakdown; opens the atlas for the per-row detail when escalating a deferral.

## Source-citation discipline

The Acceptance Source column in the atlas's matrix MAY cite:

- **PRD section** — `PRD § AC US-NN` (the canonical citation; works when step 8 used per-US-NN acceptance criteria) OR `PRD § Requirements § P0-N` (when AC is in the Requirements table).
- **Step-4 finding ID** — `F-NN resolved at screen NN` when a step-4 finding closed inline at step 13 (mirrors step-11 KEEP 5 + step-12 inheritance). Example: `PRD § AC US-07; F-12 resolved at screen 05`. The F-NN citation closes the trace from observed-user-pain (step 4) → user-story (step 8) → shipped-fix on a screen (step 13).
- **Step-7 inheritance** — `step 7 screens/<name>; revised at step 13 for <reason>` when the screen extends a step-7 screen with v3-specific changes.

NOT valid:
- **Empty Source column** — every row needs a citation.
- **Vague citation** — `PRD` alone (without section) is not a citation; `step 8` alone is not a citation.

## When step 8 PRD revises mid-atlas

Step 13 reads step 8 PRD at synthesis time. If the founder revises step 8 PRD AFTER step 13 fires (adds a US-NN, changes a priority), the atlas matrix is stale. Two valid recovery paths:

1. **Re-run step 13** with the revised PRD. The matrix re-derives from the current PRD; old rows that no longer exist disappear; new rows appear with status `covered` or `deferred` per the new screens.
2. **Manually update the atlas matrix** (founder-driven, post-step-13 review). The atlas is a markdown file; the founder edits the matrix to reflect the PRD revision. The `## PRD coverage: X/Y` line updates by hand.

Path 1 is the discipline; Path 2 is the escape hatch. Don't ship a stale atlas to engineering — `/sdd new <slug>` reads the atlas as the visual contract; a stale matrix breaks the contract.

## When step 8 PRD is genuinely sparse (low US-NN count)

For micro-products / CLI helpers, step 8 PRD may have 3-5 US-NNs only. The matrix is short. The coverage score is still meaningful: `3/3` or `4/5` is a valid score; the atlas doesn't pad the matrix with invented rows. Step 8's depth-calibration discipline applies upstream — a short PRD produces a short matrix, not a regression.

## Sweet-spot calibration within SMB SaaS (N=6 vs N=9)

The prompt's § 3 calibration table lands SMB SaaS at **N=6-10 screens** — a range, not a single value. The agent's job is to pick within that band. This sub-section documents the trade-offs at the two ends of the band, with a worked example showing the same 16-US-NN PRD rendered at N=6 vs N=9.

### The worked example — 16 US-NNs, two N choices

A 16-US-NN SMB SaaS PRD (the spec 026 default product class). The PRD inventory triages into 3 killer-flow US-NNs (US-01/02/07 — the triage loop) + 9 supporting US-NNs (US-03 import, US-04 palette, US-05 billing, US-06 dashboard stats, US-08 issue detail, US-09 settings, US-10 onboarding progress, US-11 backlog filters, US-12 help overlay) + 4 polish US-NNs (US-13 keyboard remapping, US-14 logo customization, US-15 weekly stats, US-16 reduced-motion). Plus 1 legal-mandatory consent surface (per step 12 § Privacy Posture).

**N=6 rendering — collapsed**

1. `01-landing.html` — marketing
2. `02-signup-consent.html` — US-05 entry + legal-consent
3. `03-onboarding-import.html` — US-03, US-10
4. `04-dashboard.html` — US-06, US-15, US-11 (backlog folded into dashboard tabs)
5. `05-triage-killerflow.html` — US-01, US-02, US-07, US-08 (issue-detail folded into triage drill-in)
6. `06-settings-tabs.html` — US-09, US-12, US-13, US-14, US-16, US-04 (palette help folded under settings § Keyboard tab; settings + billing + help + palette + customization all live as tabs on one composite surface)

**N=9 rendering — separated** (matches the dogfood-A0 output)

1. `01-landing.html` — marketing
2. `02-signup-consent.html` — US-05 entry + legal-consent
3. `03-onboarding-import.html` — US-03, US-10
4. `04-dashboard.html` — US-06, US-15
5. `05-triage-killerflow.html` — US-01, US-02, US-07
6. `06-backlog-bulk.html` — US-11
7. `07-issue-detail.html` — US-08
8. `08-command-palette-help.html` — US-04, US-12, US-13
9. `09-settings.html` — US-09, US-14, US-16

### The trade-off

| Axis | N=6 wins | N=9 wins |
|---|---|---|
| **Simplicity** | Fewer files for engineering to read; one composite "settings tabs" mental model | — |
| **Render cost** | 6 × 8 KB = ~48 KB lower bound; less per-screen state-gallery coverage | — |
| **Demo-recording clarity** | — | One screen = one mental concept; founder records the killer flow as a 5-screen sequence (signup → onboarding → dashboard → triage → backlog) without composite-surface tab-switching mid-recording |
| **Concern-tag separation** | — | Settings (`[product+engineering]`) and command palette (`[design]` for keyboard-UX) and billing (`[counsel-review]` for consent) live on distinct screens — concern-routing for `/sdd` planning is per-screen, not per-tab |
| **Audit-fix density per screen** | Composite surfaces carry 3-5 routed F-NN fixes — harder to read inline | Each screen carries 0-2 routed F-NN fixes — easier to audit per file |
| **PRD coverage clarity** | One screen covers 5-6 US-NNs (composite); the per-US-NN reader has to scroll within a screen to find the right tab | One screen covers 1-3 US-NNs; the per-US-NN reader opens the named screen, finds the surface immediately |

### Decision heuristic

**If killer-flow + migration are TWO separate demos, prefer N=9** (or higher within the band). The signal: a founder who plans to record the killer flow AND a separate "switching from Jira" migration demo benefits from the screen-per-mental-concept shape at N=9 — each demo's surface list is distinct. Mirrors step-11's 4-phase-vs-5-phase trigger (the founder's narrative shape drives the structural split).

**If the killer flow IS the migration AND the founder records ONE demo**, N=6 is honest — the composite settings surface saves a render pass and matches the founder's one-demo mental model.

For the spec 026 default (16-US-NN SMB SaaS with killer-flow + migration as separable demos), **N=9 is the sweet spot within the SMB SaaS band**. The dogfood-A0 rendering landed at N=9 for this reason; N=6 would have crammed concern-tagged surfaces (settings + palette + help) into one screen, regressing the engineering-handoff per-concern routing.

### Outside the SMB SaaS band

N=11+ for an SMB SaaS PRD signals two regressions: (a) the PRD is over-scoped — escalate to step 8 revision; (b) the founder is treating step 13 as a v2 atlas — defer screens to a separate step-13-v2 run. N=5 or fewer for a 16-US-NN PRD signals composite-surface cramming — engineering reads N screens but the per-US-NN audit trail is buried. The band exists for a reason; the agent justifies any out-of-band N in REPORT.md § Run Summary.

## Anti-patterns (quick reference)

- **Silent US-NN omission** — the matrix is missing a US-NN that exists in step 8 PRD. Schema's `| US-NN |` literal anchor catches the structural shape; manual review catches the per-row gap. Inventory every US-NN at signal-extraction time.
- **`deferred` without reason** — engineering reads "deferred" and has no path to escalate. Always cite the deferral reason (Phase / Founder / Dependency).
- **`partial` overuse** — `partial` is a soft signal; if a screen is genuinely 90% there but missing one button, score the US as `covered` and surface the gap in REPORT.md § Recommendations. `partial` is for when ≥30% of the acceptance criterion is missing.
- **Source column empty** — every row needs a citation. Empty Source = discipline failure.
- **Mixed-priority screens without per-row matrix entry** — a screen covering US-04 (P0) + US-06 (P1) needs both rows in the matrix, NOT a single row labeled "screens/04-dashboard covers US-04+US-06". The per-row discipline is what makes the matrix scoreable.
- **Stale matrix shipped to engineering** — re-run step 13 when step 8 PRD revises; don't ship a stale contract.
- **US-NN renumbering across PRD revisions** — breaks the matrix silently. Step 8's append-don't-renumber discipline must hold; if it broke, the atlas is unrecoverable without manual fix-up.
