# sitemap.yaml schema — v3 (load-bearing for Step 07)

The `<out>/docs/07-sitemap.yaml` file produced by Step 07 (sitemap-IA) drives Step 15's per-route screen-writer dispatches and the screen-atlas's coverage cross-check. **The schema is enforced mechanically by the orchestrator — Step 07 is BLOCKED if `required_categories` not satisfied without explicit deferral.** This is the load-bearing root-cause fix for the Pass-E silent-undercover bug per spec 045 (ported from spec 032 Decision 5 + 13).

## Top-level shape

```yaml
slug: <kebab-case product slug, matches <out>/ basename>
platform: web | mobile
stack: next | expo
required_categories:
  - marketing
  - auth
  - primary
  - admin
  - error
deferred_categories:                # optional — only present when a required category is genuinely out of v1 scope
  - name: marketing
    reason: internal-tool only — no public marketing surface in v1; revisit at v2
routes:
  - path: /
    category: marketing
    states: [default]
    covers_us: ["US-01", "US-02"]
    components: [Hero, FeatureGrid, FooterCTA]
  - path: /auth/login
    category: auth
    states: [default, loading, error]
    covers_us: ["US-03"]
    components: [LoginForm, OAuthButtons]
  - path: /auth/signup
    category: auth
    states: [default, loading, error]
    covers_us: ["US-03", "US-04"]
    components: [SignupForm, OAuthButtons]
  - path: /auth/password-reset
    category: auth
    states: [default, loading, success, error]
    covers_us: ["US-05"]
    components: [PasswordResetForm]
  # ... primary, admin, error categories follow
```

## Required fields per route

| Field | Type | Required | Constraint |
|---|---|---|---|
| `path` | string | yes | starts with `/`; matches stack convention (Next.js `/foo/[id]` for dynamic; Expo `/foo` for static) |
| `category` | string | yes | one of `marketing | auth | primary | admin | error` |
| `states` | list of strings | yes | at least 1; primary routes MUST include `default`, `loading`, `empty`, `error` (orchestrator auto-augments if missing) |
| `covers_us` | list of strings | yes | at least 1; each entry is a US-NN ref from `docs/05-prd.md` |
| `components` | list of strings | yes | at least 1; PascalCase; screen-writer treats as materialization targets |

## Required categories enforcement (the load-bearing mechanical fix)

`required_categories: [marketing, auth, primary, admin, error]` — orchestrator parses sitemap.yaml after Step 07 returns and enforces:

**Every category in `required_categories` MUST have ≥1 route OR be listed in top-level `deferred_categories: [{name, reason}]` with a non-empty reason string.**

### Per-category minimums (within required categories)

Beyond presence (≥1 route), schema enforces minimums per category:

| Category | Minimum routes | Required path patterns |
|---|---|---|
| `marketing` | 1 | `/` (landing) at minimum |
| `auth` | 3 | `/auth/login`, `/auth/signup`, `/auth/password-reset` (or equivalent paths — fuzzy match on `login`, `signup`, `password.*reset` keywords) |
| `primary` | 1 | (varies — application-specific killer-flow routes) |
| `admin` | 2 | At minimum `/settings/*` (org or account settings) + one other admin surface (team-management, billing, integrations, audit-log) |
| `error` | 1 | `/not-found` (Next.js convention `app/not-found.tsx`) at minimum |

If a category is in `required_categories` AND has fewer routes than its minimum AND has no explicit deferral, Step 07 is BLOCKED with error message naming the gap (e.g. "auth category has only 1 route (signup) but minimum is 3 — add login + password-reset, OR add to deferred_categories with reason").

### `deferred_categories` escape clause

Genuinely-out-of-v1 categories can be deferred per category:

```yaml
deferred_categories:
  - name: marketing
    reason: internal-tool only, no public marketing surface; revisit at v2 if open-sourcing
  - name: admin
    reason: single-tenant v1, no admin role distinct from primary user; multi-tenant deferred to v2
```

Each deferred entry MUST have `reason` (non-empty, 1-2 sentences). Orchestrator emits this as `## Deferred Categories` block in REPORT.md's coverage section so the founder sees the conscious tradeoff.

## Validation rules (post-Step-07 return — orchestrator-enforced, BLOCKS step on failure)

The skill runs these checks before allowing Step 07 to be marked complete:

1. **Schema parses** — valid YAML, top-level keys match shape
2. **`slug` matches** — `slug` field equals the slug derived from `--out` basename
3. **`platform` + `stack` match `--stack` flag** — sanity check
4. **5 categories accounted for** — every entry in `required_categories` has either ≥minimum routes OR is in `deferred_categories` with reason
5. **Per-route fields complete** — every route has all 5 required fields with valid types
6. **`category` values valid** — every route's `category` ∈ `[marketing, auth, primary, admin, error]`
7. **Path uniqueness** — no duplicate `path` values
8. **Component name validity** — `components` entries match `^[A-Z][A-Za-z0-9]*$`
9. **`covers_us` refs are valid US-NN** — each entry matches `^US-\d+$` and corresponds to an actual US-NN in `docs/05-prd.md` (parse PRD's user-story table; emit warning if covers_us references an US-NN not in PRD)
10. **No PRD US-NN orphan** — every US-NN with priority P0 or P1 in PRD MUST appear in some route's `covers_us` (P2 may be deferred). Orphan US-NN = warning, not BLOCK (founder may have intentionally deferred a screen).

## Parent-side validation pseudocode

```python
# Reference implementation orchestrator follows after Step 07 sub-agent returns
sitemap = yaml.safe_load(open(f"{out}/docs/07-sitemap.yaml"))
deferred = {d['name']: d['reason'] for d in sitemap.get('deferred_categories', [])}
errors = []

for required in ['marketing', 'auth', 'primary', 'admin', 'error']:
    routes_in_cat = [r for r in sitemap['routes'] if r['category'] == required]
    min_count = {'marketing': 1, 'auth': 3, 'primary': 1, 'admin': 2, 'error': 1}[required]
    if len(routes_in_cat) < min_count:
        if required in deferred:
            continue  # explicitly deferred with reason
        else:
            errors.append(f"{required} has {len(routes_in_cat)} routes, minimum {min_count} — add routes OR add to deferred_categories with reason")

if errors:
    # BLOCK Step 07; re-dispatch with augmented brief naming each missing category
    re_dispatch_with(brief + "\n\nADDITIONAL CONSTRAINT: " + " | ".join(errors))
```

## Why this schema (and not just freeform)

The 5-category requirement forces the agent to think about ALL surfaces (not just the "happy path screens" a founder mentions). Real apps have marketing pages, auth flows, primary feature surfaces, admin/settings, AND error states; omitting any of these is the most common prototype gap.

**Pass-E demonstrated this concretely** (spec 036 dogfood at `/tmp/dogfood-v2/`): Steward shipped without `auth` (the sitemap.yaml had ZERO auth routes), without `admin` beyond `/settings/policy` (no billing/team-management/org-settings), and without `error` beyond `/not-found`. Atlas declared "PRD coverage 14/15" — but the silent gap was the ENTIRE auth category. Spec 045's enforcement makes that bug structurally impossible.

Industry validation: Eleken / Slickplan / Raw.Studio / Nielsen Norman Group all enforce this category set in their sitemap deliverables. Spec 032 research (48 sources, 2026-05-17) treated sitemap-IA as own step + schema enforcement as the root-cause fix for the "atlas under-cover" symptom.

## Cross-references

- `delegation-briefs.md` § Step 07 — sub-agent brief
- `pipeline-coverage.md` § Step 07 — size targets
- `state-machine.md` § Failure handling — orchestrator retry behavior
- `SKILL.md` § Phase 2 — Specification, Step 07 acceptance check
- `docs/specs/045-prototype-skill-pipeline-realign/spec.md` § Acceptance criteria B.scenario "sitemap-IA enforces categories"
