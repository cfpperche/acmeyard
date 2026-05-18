---
mode: synthesis
delegable: true
delegation_hint: "produce sitemap.yaml — full screen inventory + IA decomposition — schema-bound to references/sitemap-schema.md's required_categories enforcement (marketing, auth, primary, admin, error); load-bearing root-cause fix for atlas under-cover bug; YAML output 2-5 KB; orchestrator parses + BLOCKS step if required_categories not satisfied without deferred_categories declaration; fully delegable from PRD + functional-spec + concept-brief"
---

# Step 07 — Sitemap-IA (full screen inventory; root-cause fix for atlas under-cover)

**Goal:** produce `<out>/docs/07-sitemap.yaml` — the canonical screen inventory for the product. This file is **load-bearing** for Step 15 atlas (drives N screen-writer dispatches) AND **enforced mechanically** by the orchestrator (parses YAML, BLOCKS step if `required_categories` not satisfied without `deferred_categories` declaration).

Per spec 045 Decision 5 + 13 (ported from spec 032): sitemap-IA is its own step (was inline in v2 Step 02 direction-writer). The dedicated step + schema enforcement is the **load-bearing mechanical fix** for the Pass-E silent-undercover bug — Steward shipped without `auth` / `admin` deeper / `error` beyond 404 because no step enforced category coverage.

**Mode:** `synthesis` with `delegable: true`. Sub-agent reads PRD + functional-spec + concept-brief and produces YAML output mechanically.

## Output

| File | Role | Floor | Ceiling |
|---|---|---|---|
| `<out>/docs/07-sitemap.yaml` | full screen inventory, schema-enforced category coverage | 2 KB | 5 KB |

## Inputs (read first)

- `<out>/docs/05-prd.md` § User stories — every P0/P1 US-NN MUST map to ≥1 route (P2 may defer)
- `<out>/docs/03-functional-spec.md` § Pages & Surfaces — surface inventory hints
- `<out>/docs/01-concept-brief.md` — product class (B2C / B2B / internal-tool / etc) drives which `required_categories` apply
- `.claude/skills/prototype/references/sitemap-schema.md` — the binding schema (read this CLOSELY; orchestrator enforces it post-return)

## YAML shape (schema-bound)

```yaml
slug: <kebab-case product slug>
platform: web | mobile
stack: next | expo

required_categories:
  - marketing
  - auth
  - primary
  - admin
  - error

# Optional — only when a required category is genuinely out of v1 scope
deferred_categories:
  - name: marketing
    reason: <1-2 sentences explaining why category is out of v1 scope>

routes:
  - path: /
    category: marketing
    states: [default]
    covers_us: [US-01, US-02]
    components: [Hero, FeatureGrid, PricingPreview, FooterCTA]

  - path: /auth/login
    category: auth
    states: [default, loading, error]
    covers_us: [US-03]
    components: [LoginForm, OAuthButtons]

  - path: /auth/signup
    category: auth
    states: [default, loading, error]
    covers_us: [US-03, US-04]
    components: [SignupForm, OAuthButtons]

  - path: /auth/password-reset
    category: auth
    states: [default, loading, success, error]
    covers_us: [US-05]
    components: [PasswordResetForm]

  # ... primary routes (killer flow + other user-facing surfaces) ...

  - path: /settings/account
    category: admin
    states: [default, saving, error]
    covers_us: [US-09]
    components: [AccountForm]

  - path: /settings/team
    category: admin
    states: [default, loading, empty, error]
    covers_us: [US-10]
    components: [TeamMembersTable, InviteForm]

  - path: /not-found
    category: error
    states: [default]
    covers_us: []
    components: [NotFoundMessage, BackToHomeCTA]
```

## Per-category minimums (HARD — orchestrator enforces)

| Category | Min routes | Required path patterns (fuzzy keyword match) |
|---|---|---|
| `marketing` | 1 | `/` (landing) |
| `auth` | 3 | `login`, `signup`, `password.*reset` |
| `primary` | 1 | (varies — killer-flow routes from PRD) |
| `admin` | 2 | `/settings/*` + at least one other admin surface (team-management, billing, integrations, audit-log) |
| `error` | 1 | `/not-found` (Next.js `app/not-found.tsx`) |

If a `required_categories` member has fewer routes than its minimum AND is NOT in `deferred_categories`, orchestrator BLOCKS Step 07 and re-dispatches with augmented brief naming the gap.

## `deferred_categories` escape clause

Genuinely-out-of-v1 categories MUST be deferred explicitly with a reason:

```yaml
deferred_categories:
  - name: marketing
    reason: internal-tool only, no public marketing surface in v1; revisit at v2 if open-sourcing
  - name: admin
    reason: single-tenant v1, no admin role distinct from primary user; multi-tenant deferred to v2
```

Each entry MUST have `reason` (non-empty, 1-2 sentences). The deferral becomes an explicit decision in `<out>/docs/REPORT.md § Deferred Categories` so the founder sees the conscious tradeoff.

## Per-route field requirements

| Field | Type | Required | Notes |
|---|---|---|---|
| `path` | string | yes | starts with `/`; Next.js dynamic syntax `[id]`; Expo static |
| `category` | string | yes | one of `marketing | auth | primary | admin | error` |
| `states` | list[string] | yes | ≥1; primary routes MUST include `default`, `loading`, `empty`, `error` (orchestrator auto-augments if missing) |
| `covers_us` | list[string] | yes | ≥0; entries match `^US-\d+$`; orphan US-NN refs (not in PRD) emit warning |
| `components` | list[string] | yes | ≥1; PascalCase; screen-writer treats as materialization targets |

## Constraints

- 2-5 KB hard ceiling.
- Valid YAML (parses with `yaml.safe_load`).
- All required_categories accounted for (≥1 route OR deferred with reason).
- Per-category minimums met (or deferred).
- Every route has all 5 required fields.
- No duplicate paths.
- All `covers_us` entries are valid US-NN refs from PRD (warning if orphan).
- Every PRD US-NN with priority P0 OR P1 appears in ≥1 route's `covers_us` (warning if orphan US-NN).
- Top of file comment: `# Sitemap schema per spec 045 Decision 13 — enforced by orchestrator after Step 07 returns`.

## Validation flow (orchestrator side — informational; not in sub-agent's hands)

```
1. parse 07-sitemap.yaml
2. for category in [marketing, auth, primary, admin, error]:
     routes_in_cat = filter routes by category
     min = {marketing:1, auth:3, primary:1, admin:2, error:1}[category]
     if len(routes_in_cat) < min:
       if category in deferred_categories AND has reason:
         continue  # explicitly deferred
       else:
         BLOCK Step 07; re-dispatch with augmented brief naming the gap
3. emit REPORT.md § Sitemap Coverage with per-category counts + deferrals
```

## Why this step is load-bearing

Pass-E (spec 036 dogfood 2026-05-18) demonstrated the bug: Steward's sitemap.yaml (produced inline in old Step 02) listed only 5 routes — zero auth, only `/settings/policy` for admin, only `/not-found` for error. The atlas declared "PRD coverage 14/15" — but the silent gap was the ENTIRE auth category. Spec 045's promotion of sitemap-IA to own step + schema enforcement makes that bug structurally impossible.

## Cross-references

- `.claude/skills/prototype/references/sitemap-schema.md` — binding schema (full validation rules)
- `.claude/skills/prototype/references/delegation-briefs.md` § Step 07 — full sub-agent brief
- `.claude/skills/prototype/references/pipeline-coverage.md` § Step 07 — size targets + lightening
- `docs/specs/045-prototype-skill-pipeline-realign/spec.md` § Acceptance B.scenario "sitemap-IA enforces categories"
- `docs/specs/032-pipeline-industry-alignment/spec.md` § Decisions 5 + 13 — industry rationale
