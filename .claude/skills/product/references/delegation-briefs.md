# Delegation briefs — 5-field templates per sub-agent (v3)

Every `Agent` tool call dispatched by `/product` v0.3.0 MUST use the 5-field handoff per `.claude/rules/delegation.md` (TASK / CONTEXT / CONSTRAINTS / DELIVERABLE / DONE_WHEN). The delegation-gate hook returns exit 2 otherwise.

**16 briefs total:** 15 step-specific (one per pipeline step) + 1 per-stack screen-writer template (reused by Step 02 lo-fi screens + Step 15 hi-fi screens).

**Per-step model assignment** (per spec 036 Q1 resolution preserved in spec 045): Step 01 = `opus` (concept brief multi-source synthesis); Steps 02-15 = `sonnet` (mechanical with dense brief + bundled template).

**Substitution placeholders** ({{...}}) are replaced inline by the orchestrator (SKILL.md) before dispatch. The orchestrator reads `<out>/docs/.state.json` for `slug`, `idea`, `out`, `flags.stack`, `target_language` (resolved at Phase 0.5 per spec 054), and the prior-step outputs by path.

**Per spec 054, every brief producing user-facing text MUST receive `{{target_language}}` substitution.** The orchestrator threads `.state.json.target_language` into the brief at dispatch time. Sub-agents read it and match all generated copy (page headings, button labels, microcopy, marketing copy, voice samples, etc) to that language. Code-flavored surfaces (e.g. `/settings/integrations` references to `API`, `OAuth`, etc) may stay English locally; flag those as exceptions in the brand-book `## Glossary § applies_to` column.

## Phase 1 — Discovery

### Step 01 — Ideation (concept brief — extended with market sizing per Decision 6)

**model:** `opus`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce concept-brief.md for the product idea "{{idea}}" — a deep concept brief covering market fit, persona, mechanics, growth, monetization, risks, AND market sizing (TAM/SAM/SOM).

CONTEXT: Read .claude/skills/product/templates/pipeline/01-ideation/prompt.md for the canonical brief structure. Read .claude/skills/product/templates/pipeline/01-ideation/references/concept-brief-template.md for the section shape. Read .claude/skills/product/templates/pipeline/01-ideation/references/discovery-playbook.md for the 5-track market discovery process. Read .claude/skills/product/references/pipeline-coverage.md § "Per-step output + size targets" for the standard-tier calibration. Use WebSearch + WebFetch for 5-8 market discovery searches.

CONSTRAINTS:
- Standard tier: target 4-10 KB output as HARD CEILING (NOT minimum — going over by ≥50% means re-emit at smaller scope).
- **Target language: `{{target_language}}`** (BCP-47, resolved at Phase 0.5). All section bodies + persona language + tagline candidates + name candidates in this language; cited sources stay in their original language.
- Cover the standard-tier minimum sections as H2 headings: Hook (problem + audience) / Mechanics (user flow) / Monetization / Growth loop / Competitive positioning / Risks / Anti-goals / JTBD statement / **Market Sizing (TAM/SAM/SOM — 1 paragraph each, desk research with 1-2 cited sources per number, NOT primary research)**. SKIP critique-mode at standard tier.
- Cite at least 5 unique sources with inline [N] references. Market Sizing section cites at minimum 1 source per TAM/SAM/SOM number.
- Name placeholder discipline: if final product name not yet decided, use `**Working name:** <placeholder> (placeholder, never shipped; final at Step 13 brand-book § Product Name)`. Suggest 2-3 candidates.
- Do NOT invent statistics — every claim either cites a source OR is hedged ("anecdotally", "in this researcher's view").
- Write file DIRECTLY to {{out}}/docs/concept-brief.md. Do NOT create extra files.

DELIVERABLE: {{out}}/docs/concept-brief.md

DONE_WHEN: File exists; size ≤ 10 KB (hard ceiling) AND ≥ 4 KB; all 9 standard-tier sections present (H2 headings including § Market Sizing); ≥ 5 unique [N] source citations; placeholder discipline applied if name not finalized; TAM/SAM/SOM each cite ≥1 source.
```

### Step 02 — Prototype v1 (lo-fi: direction + killer-flow mood screens)

Two sub-agent dispatches: (a) one direction-writer for the visual mood board; (b) N screen-writers for the killer flow.

**(a) Direction writer — model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce direction-a.html — a single HTML mood board proposing the visual direction for "{{idea}}".

CONTEXT: Read concept-brief.md at {{out}}/docs/concept-brief.md for product persona + mechanics. Read .claude/skills/product/templates/pipeline/02-prototype/prompt.md for the canonical mood-board structure (ONE direction at standard tier). Read .claude/skills/product/references/od-catalog-index.json for the 72-vendor catalog; pick 1-2 vendors whose mood matches the product and cite by name + vendor_path. Read .claude/skills/product/templates/pipeline/02-prototype/schema.md for the 8 mandatory sections.

CONSTRAINTS:
- Standard tier: ONE direction only.
- **Target language: `{{target_language}}`** (BCP-47, resolved at Phase 0.5). All user-facing copy in the mood HTML matches this language — section headings, button labels, marketing taglines, voice samples. Code-flavored surfaces stay English locally.
- 8 mandatory sections (palette / type / hero / dashboard / charts / pricing / FooterCTA + DS lineage). Cite 1-2 OD vendors.
- Self-contained HTML — single file, inline styles + SVG.
- CSS :root custom properties (vendor-agnostic names: --color-primary, --background, --foreground).
- Includes "Most Popular" string token + ≥1 `<svg` (catalog citation discipline).
- **Do NOT produce sitemap.yaml** — that's Step 07's deliverable per spec 045 (sitemap-IA promoted to own step).
- Size budget: per `.claude/skills/product/templates/pipeline/02-prototype/schema.md § Target` (currently 10-30 KB for direction-a.html; soft overshoot trigger at max × 1.2 → partial-result with `oversize_reason`).
- Write file DIRECTLY to {{out}}/docs/direction-a.html. The 3-5 killer-flow mood screens are produced by separate per-stack screen-writer dispatches (sub-agent b — see § Per-stack screen-writer below).

DELIVERABLE: {{out}}/docs/direction-a.html (+ killer-flow HTML mood screens at {{out}}/docs/screens/NN-<name>.html produced by sub-agent b in parallel)

DONE_WHEN: File exists; size within schema target range (see schema.md § Target); contains :root + --background + --foreground + --primary tokens; contains "Most Popular"; ≥1 `<svg`; cites ≥1 OD vendor in HTML comment header.
```

**(b) Screen writer — reused by Step 02 (mood HTML) + Step 15 (real Next.js/Expo).** See § Per-stack screen-writer below.

### Step 03 — Spec (functional + architecture; extended with problem-validation interviews per Decision 6)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce functional-spec.md decomposing "{{idea}}" into pages, components, interactions, states, features with Gherkin acceptance scenarios + preliminary architecture skeleton + problem-validation interview summaries (seeds OST at Step 06).

CONTEXT: Read concept-brief.md at {{out}}/docs/concept-brief.md for product scope. Read direction-a.html at {{out}}/docs/direction-a.html + screens at {{out}}/docs/screens/ for surface inventory. Read .claude/skills/product/templates/pipeline/03-spec/prompt.md for canonical structure (standard tier combines spec + architecture into a single file). Read .claude/skills/product/templates/pipeline/03-spec/schema.md for the size budget (`§ Target`) + required sections.

CONSTRAINTS:
- Standard tier: combined functional-spec.md (skip separate architecture.md). Size budget: per schema.md § Target (12-30 KB; soft overshoot trigger at max × 1.2).
- **Target language: `{{target_language}}`** (BCP-47). All section bodies, page descriptions, Gherkin scenario text + acceptance prose in this language. Technical terms (HTTP, JSON, OAuth, etc) stay English. User-story summaries match the language.
- Sections required (H2): Product Overview / Pages & Surfaces (table per page) / Features (with Gherkin) / Navigation Map / Cross-cutting concerns / Acceptance Scenarios / Edge Cases / Non-goals / Decisions Pending / Preliminary Architecture / **Problem-Validation Interviews (3-5 summaries seeding OST; synthetic-OK at standard tier — clearly marked as synthetic vs sourced from real interviews)**.
- Scale depth to surface importance; killer flow gets full treatment; trivial pages collapse to 2-4 table rows.
- Every "Decisions Pending" row has either a source citation OR a default value.
- ≥ 3 Gherkin scenarios.
- Write file DIRECTLY to {{out}}/docs/functional-spec.md.

DELIVERABLE: {{out}}/docs/functional-spec.md

DONE_WHEN: File exists; size within schema target range (see schema.md § Target — currently 12-30 KB); contains **Given** / **When** / **Then** keywords; contains "Pages & Surfaces" + "Features" + "Preliminary Architecture" + "Problem-Validation Interviews" section headers; ≥ 3 Gherkin scenarios; ≥ 3 interview summaries.
```

### Step 04 — UX Testing (heuristic audit)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce validation-report.md — heuristic audit (Nielsen's 10 + WCAG 2.1 AA) on the Phase 1 prototype surfaces + validation mode declaration.

CONTEXT: Read direction-a.html at {{out}}/docs/direction-a.html + screens at {{out}}/docs/screens/ for rendered surfaces (PROJECTED-mode audit at standard tier). Read functional-spec.md at {{out}}/docs/functional-spec.md for declared behavior. Read .claude/skills/product/templates/pipeline/04-ux-testing/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: PROJECTED mode. Audit infers contrast / tab order / a11y from spec + HTML inspection.
- Heuristic-only — Nielsen 10 + WCAG 2.1 AA top issues.
- validation_mode: `tested` / `intuition` / `not-applicable` — default `intuition`.
- YAML frontmatter: `findings[]` with `{id, severity 1-4, heuristic, location, issue, recommendation, fix_skill_hint}` where fix_skill_hint ∈ `{design-system, screen-atlas, deferred}` (note: `prototype-v2` removed per spec 045 — Step 7 deleted; fixes that were `prototype-v2` now route to `screen-atlas`).
- ≥ 3 findings minimum.
- 5-8 KB hard ceiling.
- Write file DIRECTLY to {{out}}/docs/validation-report.md.

DELIVERABLE: {{out}}/docs/validation-report.md (with YAML frontmatter)

DONE_WHEN: File exists; size 5-8 KB; contains `Nielsen` + `WCAG`; contains `validation_mode: intuition` (or other valid value); YAML frontmatter parses with ≥ 3 findings entries each carrying severity + fix_skill_hint ∈ {design-system, screen-atlas, deferred}.
```

## Phase 2 — Specification

### Step 05 — PRD 1-pager (Lenny hybrid per Decision 1 + 15)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce prd.md — Lenny Rachitsky 1-pager hybrid for "{{idea}}". This is a TIGHT 1-pager (4-7 KB target hard ceiling), NOT a multi-page PRD.

CONTEXT: Read concept-brief.md + functional-spec.md + validation-report.md frontmatter + direction-a.html + screens at {{out}}/docs/ for product scope. Read .claude/skills/product/templates/pipeline/05-prd/prompt.md + schema.md for the Lenny hybrid shape.

CONSTRAINTS:
- 4-7 KB hard ceiling (TIGHTER than v2's 6-10). Each section ≤3 bullets to preserve 1-pager honesty.
- **Target language: `{{target_language}}`** (BCP-47). All H2 body text + user-story summaries + acceptance criteria in this language. H2 section headers themselves stay English-canonical (Problem / Why now / Success metrics / etc) because they ARE the Lenny 1-pager template — match the source attribution.
- Lenny bones (H2 in this order): Problem · Why now · Success metrics · Solution sketch · User stories · Anti-goals.
- Plus 3 our-specific sections (H2 after Lenny bones): Release scope (v1 vs v2 vs vN scoped) · NSM (dedicated slot — ONE primary metric, never two equal-priority) · Upstream/downstream refs (links to concept-brief + functional-spec + downstream sitemap/system-design slots).
- User-story IDs: zero-padded sequential US-01, US-02, ..., US-NN. APPEND-don't-renumber discipline (Step 07 sitemap-IA + Step 15 atlas coverage matrix both depend on stable IDs).
- P0/P1/P2 tiering — hard cut. Everything else is § Backlog (within Solution sketch section) or explicit § Anti-goals.
- NSM is ONE primary metric in its dedicated slot; supporting observability metrics optional, listed as read-only follow-ons.
- Spec-Pending decisions from Step 03 RESOLVED INLINE: founder-locked → apply; spec-default applies → state reason; genuinely open → § Upstream/downstream refs as "open: see followup".
- Attribution: header comment "PRD shape based on Lenny Rachitsky's 1-pager template (lennysnewsletter.com/p/prds-1-pagers-examples) — hybrid w/ Steward-specific Release scope · NSM · Upstream refs sections per spec 045 Decision 15".
- Write file DIRECTLY to {{out}}/docs/prd/v1.md.

DELIVERABLE: {{out}}/docs/prd/v1.md

DONE_WHEN: File exists; size 4-7 KB (hard ceiling); contains literal table-row `| US-NN |` (at least one); contains all 9 H2 sections (6 Lenny bones + 3 our-specific); ONE NSM in dedicated slot (NOT two equal); P0/P1/P2 tiers visible in table; attribution comment present.
```

### Step 06 — OST (Opportunity Solution Tree — new per Decision 12)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce ost.md — Opportunity Solution Tree (Teresa Torres methodology) for "{{idea}}", consuming Step 05's PRD NSM as the desired outcome root.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md for NSM (desired outcome) + user stories + anti-goals. Read functional-spec.md at {{out}}/docs/functional-spec.md § Problem-Validation Interviews for raw problem signal. Read concept-brief.md at {{out}}/docs/concept-brief.md for persona context. Read .claude/skills/product/templates/pipeline/06-ost/prompt.md for canonical OST shape. Reference: Teresa Torres, Continuous Discovery Habits (Product Talk Academy).

CONSTRAINTS:
- Standard tier: 1 desired outcome root (NSM from Step 05) → 3-5 opportunities (user problems discovered/inferred) → 2-3 solutions per opportunity.
- Each opportunity ties back to a specific Problem-Validation Interview summary OR a hedged "inferred from persona" attribution.
- Each solution is a high-level approach, NOT an implementation detail. E.g. "Inline override-reason input gating" (solution), NOT "React modal with useState" (implementation).
- Mark solutions with status: `explored` (already in scope) / `to-test` (next interview cycle) / `parked` (out of v1).
- Tree rendered as nested markdown bullets OR mermaid diagram (sub-agent's choice based on visual clarity at this depth).
- 3-6 KB hard ceiling.
- Write file DIRECTLY to {{out}}/docs/ost.md.

DELIVERABLE: {{out}}/docs/ost.md

DONE_WHEN: File exists; size 3-6 KB; tree structure with 1 outcome → 3-5 opportunities → 2-3 solutions per opportunity; every solution carries status {explored | to-test | parked}; opportunities reference Step 03 interviews OR persona inferences.
```

### Step 07 — Sitemap-IA (per Decision 5 + 13 — load-bearing root-cause fix)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce sitemap.yaml — full screen inventory + IA decomposition for "{{idea}}", schema-bound to references/sitemap-schema.md's required_categories enforcement.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md for US-NN inventory. Read functional-spec.md at {{out}}/docs/functional-spec.md § Pages & Surfaces for surface inventory. Read concept-brief.md at {{out}}/docs/concept-brief.md for product class (B2C / B2B / internal-tool / etc — drives which required_categories apply). Read .claude/skills/product/references/sitemap-schema.md for the binding schema. Read .claude/skills/product/templates/pipeline/07-sitemap-ia/prompt.md + schema.md for canonical shape.

CONSTRAINTS:
- YAML output. Top-level keys: `slug`, `platform`, `stack`, `required_categories`, `routes`, `deferred_categories` (optional).
- `required_categories: [marketing, auth, primary, admin, error]` — every member MUST have ≥1 route OR be listed in `deferred_categories: [{name, reason}]`.
- For B2C SaaS / B2B SaaS: all 5 required. For internal-tool/CLI/back-office-only: `marketing` may be deferred with reason "internal-tool, no marketing surface".
- Per-route fields: `path` (string) · `category` (one of required_categories) · `states` (array — default/loading/empty/error/disabled/success as applicable) · `covers_us` (array of US-NN refs from PRD) · `components` (array of component names — for downstream Step 15 wiring).
- Auth category MUST include AT MINIMUM: login + signup + password-reset (3 routes). Optionally: invite-accept, email-verify, oauth-callback.
- Admin category MUST include AT MINIMUM: org-settings + team-management (2 routes). Optionally: billing, audit-log, integrations.
- Error category MUST include AT MINIMUM: not-found (1 route). Optionally: server-error (500), forbidden (403), maintenance.
- Primary category covers the killer-flow screens from Step 02 + any other user-facing primary surfaces from PRD user stories.
- Marketing category covers landing + pricing + feature pages.
- If `deferred_categories` is used, each entry MUST include `reason` (1-2 sentences explaining why category is out of v1 scope).
- 2-5 KB hard ceiling.
- Write file DIRECTLY to {{out}}/docs/sitemap.yaml.

DELIVERABLE: {{out}}/docs/sitemap.yaml

DONE_WHEN: File exists; valid YAML; size 2-5 KB; required_categories enforced per schema (every category has ≥1 route OR is in deferred_categories with reason); ≥3 auth routes; ≥2 admin routes; ≥1 error route; every route has all required fields; covers_us refs are valid US-NN from prd.md.

NOTE: Orchestrator parses this YAML after sub-agent returns and BLOCKS step + re-dispatches with augmented brief naming the missing category(ies) if required_categories not satisfied without deferral. See SKILL.md § Phase 2 Step 07 acceptance check.
```

### Step 08 — System Design (extended with RACI + risk + data-flow per Decision 10)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce system-design.md + security.md + data-flow.json for "{{idea}}". System-design includes RACI matrix + risk register per spec 045. Data-flow.json is the structured inventory consumed by Step 09 legal for DPIA trigger.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (scope drives scale assumption) + sitemap.yaml at {{out}}/docs/sitemap.yaml (route inventory drives integration list + auth requirements) + functional-spec.md at {{out}}/docs/functional-spec.md (preliminary architecture) + concept-brief.md at {{out}}/docs/concept-brief.md (product class + audience). Read .claude/skills/product/templates/pipeline/08-system-design/prompt.md + schema.md.

CONSTRAINTS:
- system-design.md: BRIDGE-FLOOR (6+ sections H2): Stack / Integrations / Data Model / Decisions Locked / Security / Observability / **RACI Matrix** / **Risk Register**. Size budget: per `.claude/skills/product/templates/pipeline/08-system-design/schema.md § Target` (15-42 KB; soft overshoot trigger at max × 1.2).
- RACI Matrix: 5-10 key roles (founder/engineer/designer/data/legal/...) × 5-10 key activities (auth/payments/audit-trail/...). Each cell: R/A/C/I or blank.
- Risk Register: 5-10 risks with columns: ID · description · probability (L/M/H) · impact (L/M/H) · mitigation · owner.
- Stack baseline (adapt per product needs): Next.js 16 (matches prototype) + Postgres + Redis + Slack Bot SDK + LLM API (if needed) + S3-compatible blob.
- Integrations table: name · purpose · sub-processor? · data-flow direction · v1-vs-v2.
- Decisions Locked: 6-10 architectural decisions with one-line rationale.
- security.md: STRIDE-lite threat model + auth/authz + data classification + secrets handling + AI-specific section if LLM in stack. Size: 3-10 KB (per schema.md § Target).
- **data-flow.json: structured machine-readable inventory.** Schema: `{"flows": [{"from": "<source>", "to": "<sink>", "data_categories": ["pii" | "health" | "minors" | "financial" | "behavioral" | "credentials" | "session" | "telemetry"], "encryption_at_rest": bool, "encryption_in_transit": bool, "retention_days": int | null, "sub_processor": string | null}]}`. Cover ALL data flows the system handles. Consumed by Step 09 legal — if ANY flow includes `pii | health | minors | financial`, Step 09 fires DPIA section as mandatory.
- Write 3 files DIRECTLY to {{out}}/docs/: 08-system-design.md + 08-security.md + 08-data-flow.json.

DELIVERABLE: 3 files: {{out}}/docs/system-design.md + {{out}}/docs/security.md + {{out}}/docs/data-flow.json

DONE_WHEN: system-design.md size within schema target range (see 08-system-design/schema.md § Target — currently 15-42 KB) + 8 H2 sections present (including RACI Matrix + Risk Register); security.md size within target range (3-10 KB) + contains "Threat Model" + "Auth" + "Data Classification" + "Secrets" section headers; data-flow.json valid JSON parses cleanly with `flows` array containing ≥3 entries.
```

### Step 09 — Legal posture (shift-left per Decision 4 — DPIA-triggered by Step 08)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce legal-posture.md — founder's articulated legal posture briefing for v1 of "{{idea}}". This is BRIEFING for counsel, NOT the actual Terms/Privacy/DPA documents. Includes DPIA section IF Step 08 data-flow includes sensitive categories.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (audience drives jurisdiction exposure) + system-design.md at {{out}}/docs/system-design.md (Integrations name every sub-processor) + **data-flow.json at {{out}}/docs/data-flow.json (parses flows[]; if any flow has data_categories ⊃ {pii, health, minors, financial}, DPIA section is MANDATORY)** + concept-brief.md at {{out}}/docs/concept-brief.md (audience). Read .claude/skills/product/templates/pipeline/09-legal/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: BRIEF CHECKLIST + POSTURE. Size budget: **conditional model** per `.claude/skills/product/templates/pipeline/09-legal/schema.md § Target` — base 5-10 KB + DPIA (+5/+12) + AI-Specific (+2/+5) + Regulated Aspects (+2/+8). Compute effective floor/ceiling by summing base with each triggered condition. Soft overshoot at effective max × 1.2 → partial-result with `oversize_reason`.
- TOP-OF-DOCUMENT escape clause (line 1-5): "This is founder's posture, NOT legal advice. Counsel review required before launch."
- Sections required (H2): Terms Model / Privacy Posture (regulation applicability checklist GDPR/LGPD/CCPA Yes/No based on audience) / Data Handling Snapshot / Licensing (product license + OSS compatibility flag) / Sub-Processor Disclosure (extracted from system-design § Integrations — count must match) / IP Assignment Posture / Open Decisions.
- **§ DPIA (conditional — fires if data-flow.json contains sensitive categories):** Required when Step 08 data-flow has any `data_categories ⊃ {pii, health, minors, financial}`. Lists each sensitive data flow, the legal basis (consent/contract/legitimate-interest/legal-obligation/vital-interest/public-task), the data subject rights affected (access/erasure/portability/restriction), and the risk-mitigation posture. **DPIA-shift-left per GDPR Art 25 + IAPP guidance** — counsel reviews DPIA section in 1-pager form BEFORE coding starts, not after launch.
- § AI-Specific (conditional — fires if system-design Integrations includes LLM API): agent-data ingestion classification, model-provider relay disclosure, opt-in/opt-out posture, model retention by provider.
- § Regulated Aspects (conditional — fires if PRD audience touches health/minors/payment/enterprise/etc).
- If a conditional section's trigger isn't met, OMIT entirely (do NOT emit as "N/A").
- Default posture: MIT for OSS harness; SaaS ToS for hosted; standard DPA for paying customers; AGPL not chosen; CLA optional v1.
- Write file DIRECTLY to {{out}}/docs/legal-posture.md.

DELIVERABLE: {{out}}/docs/legal-posture.md

DONE_WHEN: File exists; size within schema-computed effective range (base 5-10 KB + sum of triggered conditional additions per schema.md § Target); escape clause at TOP (line 1-5); contains "Terms" + "Privacy" + "Licensing" + "Sub-Processor" + "Open Decisions" section headers; § DPIA present IF data-flow.json contains sensitive categories; § AI-Specific present IF LLM in Integrations; sub-processor count matches system-design integration count.
```

### Step 10 — Roadmap (defines phases for Step 11 cost — per spec 045 cost↔roadmap swap)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce roadmap.md — 3-phase MVP/Growth/Polish sketch for v1 of "{{idea}}". Phase boundaries defined HERE drive Step 11's per-phase cost calculation.

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (user stories + priorities) + system-design.md at {{out}}/docs/system-design.md (dependencies + integrations driving build sequence) + concept-brief.md at {{out}}/docs/concept-brief.md (product class) + validation-report.md at {{out}}/docs/validation-report.md (validation_mode drives canonical-vs-bridge mode). Read .claude/skills/product/templates/pipeline/10-roadmap/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: 3-phase sketch (MVP / Growth / Polish) with phase titles USER-FLOW SHAPED (e.g. "Install harness, see first override-marker hit") NOT label-shaped ("Foundation").
- Mode by validation_mode: `tested` → canonical timeline-aware (week ranges + milestones + buffer); `intuition`/`not-applicable` → bridge mode (priority-tier grouping P0→MVP, P1→Growth, P2→Polish, no week commitments).
- Slices end-to-end user value (Shape Up style) — NO horizontal layers like "Phase 1: all backend".
- Deliverables table per phase: rows reference Step-05 US-NN.
- Milestones are observable end-of-phase deliverables.
- § Overview 2-3 one-liners. § Horizon (duration estimate + team shape). § Open Decisions table.
- Size budget: per `.claude/skills/product/templates/pipeline/10-roadmap/schema.md § Target` (6-18 KB; soft overshoot trigger at max × 1.2).
- Write file DIRECTLY to {{out}}/docs/roadmap.md.

DELIVERABLE: {{out}}/docs/roadmap.md

DONE_WHEN: File exists; size within schema target range (see schema.md § Target — currently 6-18 KB); 3 phase headers present + each phase has 1-3 milestones + deliverables table per phase + § Open Decisions section; phase titles are user-flow-shaped (NOT generic labels like "Foundation").
```

### Step 11 — Cost Estimate (per-phase using Step 10's roadmap — spec 045 swap)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce cost-estimate.md — single-scenario burn rate + run-cost line items for v1 of "{{idea}}", calculated PER PHASE using Step 10's roadmap phase boundaries (spec 045 cost↔roadmap swap).

CONTEXT: Read **roadmap.md at {{out}}/docs/roadmap.md (phase boundaries drive cost calculation — load-bearing for per-phase breakdown)** + system-design.md at {{out}}/docs/system-design.md (stack + integrations drive line items) + legal-posture.md at {{out}}/docs/legal-posture.md (DPIA + counsel review budget) + prd.md at {{out}}/docs/prd/v1.md (success metric drives scale assumption). Read .claude/skills/product/templates/pipeline/11-cost-estimate/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: SINGLE-SCENARIO only. 5-8 KB hard ceiling.
- Build cost as a RANGE per phase from Step 10 roadmap (Phase 1 / Phase 2 / Phase 3 user-flow titles). Includes hourly/weekly rate assumption with source/confidence. Default $150-200/hr senior IC range with "indie founder-rate" caveat.
- Run cost line items at v1 scale: tabular per vendor (vendor / tier / monthly cost / source). Count must match system-design § Integrations list (audit discipline).
- **Legal review + audit costs in their own table row** — pulls from Step 09 legal posture (counsel-review hours estimate + SOC 2 audit if applicable).
- Assumptions table required — every input has source + confidence (high/med/low).
- Top 5 financial risks (one-liner each).
- 3-5 Recommendations with action verbs + "flip if" deciding signal.
- SKIP unit economics + sensitivity analysis + scenario analysis.
- Required H2 sections: Assumptions / Build Cost / Run Cost / Legal & Audit Budget / Risks / Recommendations.
- Write file DIRECTLY to {{out}}/docs/cost-estimate.md.

DELIVERABLE: {{out}}/docs/cost-estimate.md

DONE_WHEN: File exists; size 5-8 KB; contains "Assumptions" + "Build Cost" + "Run Cost" + "Legal & Audit Budget" + "Recommendations" section headers; build cost rows reference Step 10 roadmap phase names; run-cost vendor count matches system-design integration count.
```

### Step 12 — GTM-launch (new per Decision 7 — positioning + launch + pricing)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce gtm-launch.md — positioning canvas (April Dunford methodology) + 4-week launch plan sketch + pricing strategy for v1 of "{{idea}}".

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (NSM + audience for positioning) + concept-brief.md at {{out}}/docs/concept-brief.md (competitive positioning + monetization tier hints) + roadmap.md at {{out}}/docs/roadmap.md (launch timing aligns with roadmap Phase 1 close) + legal-posture.md at {{out}}/docs/legal-posture.md (compliance signals affect launch claims). Read .claude/skills/product/templates/pipeline/12-gtm-launch/prompt.md + schema.md. Reference: April Dunford, Obviously Awesome.

CONSTRAINTS:
- Standard tier: 4-7 KB hard ceiling.
- **Target language: `{{target_language}}`** (BCP-47). Positioning Canvas body lines + launch plan milestones + pricing tier descriptions in this language. The 5 canvas line-labels (`For:`, `Who:`, `We are:`, `Unlike:`, `Our product:`) stay English per Dunford template.
- Required H2 sections: Positioning Canvas / Launch Plan / Pricing Strategy / Open Decisions.
- **Positioning Canvas** (Dunford-lite, 3 lines minimum):
  - For: [target customer]
  - Who: [problem statement — what they're trying to do]
  - We are: [category] that [unique value]
  - Unlike: [primary alternative — competitor OR status quo / DIY]
  - Our product: [primary differentiator]
- **Launch Plan**: 4-week sketch (week-by-week milestones — e.g. week 1 = soft launch waitlist, week 2 = ProductHunt, week 3 = founder content amplification, week 4 = paid acquisition test). Each milestone has 1-3 deliverables + measurement.
- **Pricing Strategy**: tier shape (free/standard/pro structure if relevant; usage-based vs seat-based decision; freemium-vs-trial decision). Reference concept-brief monetization tiers.
- SKIP full launch playbook (post-PMF concern); skip funnel modeling (insufficient data at v1).
- Write file DIRECTLY to {{out}}/docs/gtm-launch.md.

DELIVERABLE: {{out}}/docs/gtm-launch.md

DONE_WHEN: File exists; size 4-7 KB; contains all 4 H2 sections; positioning canvas has all 5 lines (For/Who/We-are/Unlike/Our-product); launch plan has 4 week-numbered milestones; pricing strategy declares tier shape.
```

## Phase 3 — Identity

### Step 13 — Brand book (moved after Specification per Decision 3 — PRD-first)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce brand-book.md — voice + visual direction posture + we-are/we-are-not contrast pair for "{{idea}}".

CONTEXT: Read prd.md at {{out}}/docs/prd/v1.md (finalized scope + NSM + persona) + gtm-launch.md at {{out}}/docs/gtm-launch.md (positioning canvas already locked — brand voice should reinforce, not contradict) + concept-brief.md at {{out}}/docs/concept-brief.md (audience + product class) + direction-a.html at {{out}}/docs/direction-a.html (visual lineage). Read .claude/skills/product/templates/pipeline/13-brand/prompt.md for canonical 7-section structure (we target 2-3 section snapshot at standard tier).

CONSTRAINTS:
- Standard tier: voice (1-2 paragraphs) + voice samples + ONE "We are / We are not" pair minimum + **`## Language` section (spec 054)** + **`## Glossary` section (spec 054)** + Visual Direction posture + Logo Direction (clear-space + min-size + ≥3 prohibited uses) + Color Story + Anti-Patterns.
- **Target language: `{{target_language}}`** (BCP-47, from `.state.json.target_language` resolved at Phase 0.5). All voice samples, "We are / We are not" pairs, anti-pattern bullets, color-story prose, and other brand prose in this language. The `## Language` section declares this target as a machine-readable `**target_language:** <bcp47>` line.
- **Glossary obligation (spec 054):** the `## Glossary` H2 has two sub-sections — `### We say` (preferred terms / phrasing the brand favors) and `### We don't say` (avoided terms with native replacement, reason, and applies_to scope). 4-column table format: `| Term | Replacement | Reason | Applies to |`. Cap ≤ 20 entries per sub-section. Identify entries ORGANICALLY from concept-brief + positioning + product domain — domain jargon the founder uses naturally, voice traps the comparables fall into, anglicisms the brand should localize. **DO NOT auto-derive from positioning Unlike-clause** (positioning is product-vs-product level; glossary is copy-trap level; mechanical translation produces noise). Downstream Step 15 screen-writers consume `### We don't say` as a string-replace lookup.
- Voice samples: 3 minimum (one-liner per surface type — headline, microcopy, CTA label).
- Visual Direction names the feel (e.g. "Cool Brutalist", "Warm Premium") + 2-3 posture decisions (e.g. "hairline 1px borders only" / "monospace dominant" / "single saturated accent"). NO hex codes (Step 14 handles).
- "We are / We are not" pair: contrast — NOT a flat adjective list.
- **Product Name decision** required — pick one of the candidates from concept-brief OR propose better with rationale. THIS is the moment to finalize the name (Step 15 atlas + downstream artifacts propagate).
- Voice must REINFORCE Step 12 positioning canvas (e.g. if positioning says "Unlike: enterprise sales-cycle vendors" → brand voice must NOT sound corporate-sales).
- Header includes **Version:** 0.1 and **Date:** <today>.
- 4-8 KB hard ceiling.
- Write file DIRECTLY to {{out}}/docs/brand-book.md.

DELIVERABLE: {{out}}/docs/brand-book.md

DONE_WHEN: File exists; size 4-8 KB; contains **Version:** + **Date:** + `## Language` H2 + `**target_language:**` declaration + **We are** + **We are not** + 3+ voice samples + `## Glossary` H2 with both `### We say` + `### We don't say` sub-sections (each carrying a 4-column table with ≥1 entry) + visual-direction posture (named feel + 2+ posture decisions) + Product Name decision; voice alignment with Step 12 positioning is stated (1 sentence cross-ref).
```

### Step 14 — Design System (renamed from v2 Step 06; tokens path changed)

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce tokens.css + components.md + README.md (3 files inside `{{out}}/docs/design-system/`) applying the brand-book to concrete semantic design tokens for "{{idea}}". Catalog-path PREFERRED (cite 1-2 OD vendors).

CONTEXT: Read brand-book.md at {{out}}/docs/brand-book.md for posture + voice. Read sitemap.yaml at {{out}}/docs/sitemap.yaml for component scope (what surfaces need styling). Read concept-brief.md at {{out}}/docs/concept-brief.md for product class. Read .claude/skills/product/references/od-catalog-index.json for the 72-vendor catalog — pick 1-2 vendors whose mood + category match the brand-book; their DESIGN.md path (vendor_path field) is the lineage citation source. Read validation-report.md at {{out}}/docs/validation-report.md frontmatter `findings[]` and filter `fix_skill_hint: "design-system"` — these are token tunes to apply. Read .claude/skills/product/templates/pipeline/14-design-system/prompt.md + schema.md.

CONSTRAINTS:
- Standard tier: catalog path PREFERRED — if 1-2 vendors match, inherit their tokens with brand-tuned overrides. Custom path fallback only.
- Semantic token names ONLY — `--color-primary` not `--color-blue-500`; `--space-md` not `--space-12`. NO visual naming.
- **tokens.css written to {{out}}/docs/design-system/tokens.css** (NOT root — root reserved for runtime per spec 036 finding #7 iter-2). The skeleton's `app/globals.css` imports it relative as `@import "../docs/design-system/tokens.css"`.
- tokens.css: dark-first :root block + @media (prefers-color-scheme: light) overrides for color tokens. Includes color (8-14 colors) + spacing (5-7 scale) + radius (3) + font (sans + mono + 5-7 size scale).
- components.md: per-component anatomy + variants + states for at least Button / Input / Card / Table / Badge / Dialog / EmptyState. 3+ KB.
- README.md (design-system overview): overview + tokens narrative + audit-response section (which step-04 findings applied as token tunes) + catalog lineage citations. 8+ KB. Required H2: "Audit Response".
- Write 3 files DIRECTLY to {{out}}/docs/design-system/: tokens.css + components.md + README.md.

DELIVERABLE: 3 files at {{out}}/docs/design-system/: tokens.css + components.md + README.md

DONE_WHEN: tokens.css ≥ 1.5 KB valid CSS with :root block + light-mode @media override; components.md ≥ 3 KB; README.md ≥ 8 KB + contains "Audit Response" section header + cites OD vendor name + vendor_path.
```

## Phase 4 — Visual contract

### Step 15 — Screen atlas (renamed from v2 Step 13; absorbs deleted v2 Step 7 per Decision 8 + 14)

Two-part dispatch — **SERIALIZED per spec 052**: (a) atlas writer runs FIRST and writes the route-group layout files + atlas index; (b) N screen writers fan-out AFTER the atlas returns (they consume the layout files atlas just wrote, so atlas-before-writers is mandatory).

**(a) Atlas writer — model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Produce screen-atlas.md AND the route-group layout files (`app/(app)/layout.tsx` for shared chrome of primary+admin routes; optional `app/(marketing)/layout.tsx` for marketing nav if sitemap declares ≥3 marketing routes) for the complete prototype of "{{idea}}".

CONTEXT: Read ALL prior artifacts at {{out}}/docs/ (semantic-named per spec 048; pipeline order via REPORT.md):
- Phase 1 (Discovery): concept-brief.md, functional-spec.md, validation-report.md
- Phase 2 (Specification): prd/v1.md (US-NN inventory — load-bearing for PRD coverage), ost.md, sitemap.yaml (route inventory — load-bearing for screen coverage; **and source-of-truth for which routes go under `app/(app)/` vs flat**), system-design.md + security.md + data-flow.json, legal-posture.md (legal-mandatory surfaces — consent dialog if DPIA fires), roadmap.md, cost-estimate.md, gtm-launch.md
- Phase 3 (Identity): brand-book.md, design-system/tokens.css, design-system/components.md, design-system/README.md
Read .claude/skills/product/templates/pipeline/15-screen-atlas/prompt.md + schema.md for atlas shape.

CONSTRAINTS:
- Size budget: per `.claude/skills/product/templates/pipeline/15-screen-atlas/schema.md § Target` (10-28 KB for screen-atlas.md; soft overshoot trigger at max × 1.2). NOT a re-render of any single screen — the atlas IS the index.
- Required H2 sections (verbatim): Overview / Screens Index / Sitemap Coverage Cross-Check / PRD Coverage Matrix / Design Fidelity / States Coverage Matrix / User Flow Walkthrough / Open Decisions.
- **Sitemap Coverage Cross-Check** (NEW per spec 045) — for every route in sitemap.yaml, atlas confirms the corresponding `app/<route>/page.tsx` was actually generated. Missing screens listed as `[GAP — re-dispatch screen-writer]`.
- **Screens Index** — table: filename | route path | category | covers_us | states implemented.
- **PRD Coverage Matrix** — list EVERY US-NN from prd.md. For each: covered → screen filename(s) OR deferred → one-line reason.
- **Design Fidelity** — 4-dim per screen: Token Hygiene / Voice Match / Component Reuse / Brief Fit; score 1-5 per dim; Min column gates ≥ 3.
- **States Coverage Matrix** — screens × {loading/empty/error/disabled/success}; cells: ✓/—/`[gap]`.
- **User Flow Walkthrough** — killer flow end-to-end with copy snippets at each step.
- **Open Decisions** — 4-6 v1→v2 decisions deferred.
- This atlas IS the brand+tokens-applied hi-fi pass (Step 7 prototype-v2 from v2 was deleted per spec 045 Decision 8). The screens MUST consume var(--*) tokens from `docs/design-system/tokens.css`, NOT raw hex.
- Write atlas file DIRECTLY to {{out}}/docs/screen-atlas.md.
- **Route-group layouts (spec 052 + 055):** Inspect sitemap.yaml and write ONE `app/(<chrome>)/layout.tsx` PER DISTINCT `chrome` value that has ≥1 route assigned to it (use the default-inference table from `sitemap-schema.md § chrome` for routes missing explicit `chrome:`). Concrete layouts to consider:
  - `app/(app)/layout.tsx` — shared sidebar + topbar for the authenticated product surfaces (`chrome: app` routes; typically primary + admin categories). Links derived from sitemap, labels from display name or kebab-to-Title-case.
  - `app/(marketing)/layout.tsx` — marketing nav (header + footer) for `chrome: marketing` routes.
  - `app/(booking)/layout.tsx` — minimal white-label shell for `chrome: booking` routes (e.g. clinic-branded tutor portals, public funnels). Clinic/product brand header only; no nav back to authenticated app.
  - `app/(auth)/layout.tsx` — auth shell for `chrome: auth` routes (logo, language switcher, "back to marketing" link).
  - `chrome: chromeless` routes get NO layout file — they sit flat at `app/<path>/page.tsx`.

  All layouts are Server Components (NO `'use client'` at top — interactive children handle their own client boundaries per spec 051). Tokens-only (NO hex/px except 1px borders). Each layout's specific shell content (which links / what header shape) is the atlas's design call, anchored against `docs/brand-book.md` voice + `docs/design-system/components.md` for visual primitives.
- The root `app/layout.tsx` stays untouched by atlas — it's the HTML/body shell with metadata only (spec 051 covers its placeholder substitution).

DELIVERABLE: {{out}}/docs/screen-atlas.md + {{out}}/app/(app)/layout.tsx + optionally {{out}}/app/(marketing)/layout.tsx

DONE_WHEN: All 3 files exist (atlas + (app)/layout.tsx + optional (marketing)/layout.tsx); atlas size within schema target range (see schema.md § Target — currently 10-28 KB); atlas contains all 8 H2 section headers; Sitemap Coverage Cross-Check lists every route from sitemap.yaml with status; PRD coverage matrix lists every US-NN from prd.md; design-fidelity table has 4-dim Min column; `(app)/layout.tsx` exists with sidebar nav matching sitemap primary+admin categories, tokens-only, no `'use client'` directive.
```

**(b) Screen writer:** see § Per-stack screen-writer below. N = all sitemap.yaml routes (NOT killer-flow only — full sitemap coverage at standard tier per spec 045 Decision 13 sitemap schema enforcement).

## Per-stack screen-writer (reused by Step 02 lo-fi mood + Step 15 hi-fi atlas)

Dispatched ONCE PER ROUTE, capped at 5 concurrent. Brief is templated per stack + step-context.

**Brief is execution-strategy-agnostic (spec 057).** The same brief body works whether the parent dispatches it to a sub-agent (`Agent` call) OR writes it directly (parent-write fallback when fan-out degrades per spec 057). Sub-agent vs parent is an orchestration choice; the brief contract (what to produce + how to verify done) does not change. When a wave triggers the fan-out fallback (N=1 same-wave loop-budget exhaustion), the parent reads this brief and emits `page.tsx` directly via `Write`; the brief's CONTEXT / CONSTRAINTS / DONE_WHEN apply identically.

### Next.js stack

**model:** `sonnet`  ·  **subagent_type:** `general-purpose`

```
TASK: Write the Next.js page file for route {{path}} in the {{slug}} prototype ({{step_label}} pass).

CONTEXT:
- Pipeline step context: {{step_label}} (02 = lo-fi pre-brand mood HTML at {{out}}/docs/screens/, 15 = hi-fi brand-tuned page.tsx in {{out}}/app/).
- Sitemap entry source: {{out}}/docs/sitemap.yaml (route fields: path / category / states / covers_us / components)
- Tokens (Step 15 only): {{out}}/docs/design-system/tokens.css (consumed via the `app/globals.css` `@import "../docs/design-system/tokens.css"` line — use `var(--color-*)` inline / Tailwind utility-classes that resolve to the token names)
- Voice (Step 15 only): {{out}}/docs/brand-book.md (match ON-brand voice for copy) — **specifically read `## Language` for `target_language` + `## Glossary § We say / We don't say` for the term-replacement lookup (spec 054)**
- Components reference (Step 15 only): {{out}}/docs/design-system/components.md
- Stack defaults: .claude/skills/product/references/stack-defaults.md § Next.js
- Target file (Step 15 — **`chrome` field determines route-group per spec 055**; orthogonal to `category` which is PRD-coverage semantic only):
  - `chrome: app` → `{{out}}/app/(app){{path_to_file_path}}/page.tsx` (shared sidebar+topbar inherited from `app/(app)/layout.tsx`)
  - `chrome: marketing` → `{{out}}/app/(marketing){{path_to_file_path}}/page.tsx` (marketing header+footer from `app/(marketing)/layout.tsx`)
  - `chrome: booking` → `{{out}}/app/(booking){{path_to_file_path}}/page.tsx` (minimal/white-label shell from `app/(booking)/layout.tsx`)
  - `chrome: auth` → `{{out}}/app/(auth){{path_to_file_path}}/page.tsx` (auth shell — logo + lang switcher — from `app/(auth)/layout.tsx`)
  - `chrome: chromeless` → flat `{{out}}/app{{path_to_file_path}}/page.tsx` (no shared layout; root marketing landing `/`, error pages, etc)
  - Dynamic routes like `/check-in/[appointmentId]` → preserve the bracketed segment in the route-group path: `{{out}}/app/(app)/check-in/[appointmentId]/page.tsx`
  - **Sitemap missing `chrome:` field?** Apply default-inference table from `sitemap-schema.md § chrome — orthogonal to category` (`primary/admin → app`, `marketing → marketing`, `auth → auth`, `error → chromeless`). Back-compat ONLY; new sitemaps should always emit `chrome`.
- Target file (Step 02): {{out}}/docs/screens/{{NN}}-{{name}}.html (self-contained HTML, inline styles, mood-only — route groups don't apply to lo-fi mood phase)

CONSTRAINTS:
- ≤ 3 component definitions per file (extract to {{out}}/app/_components/ if needed).
- Token reads via var(--color-*) inline OR Tailwind utility classes that map to tokens — NO hard-coded #hex or px values (1px borders idiomatic CSS exception).
- Mock data inline OR in {{out}}/lib/mock-data.ts.
- Soft token budget: 4000 tokens output.
- Buttons: explicit type attribute (Biome a11y).
- **Chrome inheritance via route-group layout (spec 052) — DO NOT REINVENT.** The shared sidebar + topbar lives in `{{out}}/app/(app)/layout.tsx` (written by the atlas before this dispatch). Your `page.tsx` renders the route's UNIQUE content body ONLY — no sidebar, no topbar, no app-wide navigation chrome. If you find yourself writing `<Sidebar>` or `<TopNav>` inside `page.tsx`, stop: the layout already provides them. Pages whose category routes them outside `app/(app)/` (marketing/auth/booking) similarly inherit from `app/(marketing)/layout.tsx` or no layout (chromeless) — adapt accordingly.
- **State rendering — use Next.js sibling files, NOT inline mode chips (spec 052).** Sitemap entry `states: [loading]` → emit `<route>/loading.tsx` (Server Component skeleton, fallback for the route's Suspense boundary). `states: [error]` → emit `<route>/error.tsx` (Client Component with `'use client'`, accepts `{ error, reset }` props, includes a "Try again" button calling `reset()`). `states: [404]` or `states: [not-found]` → emit `<route>/not-found.tsx` (rendered when the page calls `notFound()` from `next/navigation`). **Empty state is page-internal rendering logic** (data-driven `if (items.length === 0) return <EmptyState />` branch) — NOT a developer-mode toggle. Skeleton root-level defaults at `app/{loading,error,not-found}.tsx` are inherited when no per-route override exists (nearest-wins per Next.js convention).
- **DO NOT embed `default | loading | empty | error` toggle chips in production page bodies (spec 052).** Anti-pattern caught in 2026-05-18 audit: sub-agents had been adding `useState<"default" | "loading" | "empty" | "error">` plus a chip row showing those words as developer-mode switches, bleeding dev-mode UI into the product surface. The chips MUST NOT appear in shipped pages. State demonstration belongs in the sibling files above (Next.js handles when to render them); developer-mode state inspection happens via the dev server's HMR, not embedded controls.
- **Per-route `metadata` export REQUIRED (spec 053 — Step 15 only).** Every `page.tsx` (Step 15 hi-fi) MUST export `export const metadata: Metadata = { title, description }` where `title` matches the route's human-readable display name (derived from sitemap path + category) and `description` matches its purpose (one sentence, on-brand voice). Root marketing page (`app/page.tsx`) inherits from `app/layout.tsx` — exception. Reason: dogfood-2 (Vetro) shipped 22/24 routes inheriting root title, hurting browser-tab orientation + SEO. Self-check before DONE: `grep -L "export const metadata" <target>/page.tsx` MUST be empty (file is missing the export) only for `/`. Lo-fi mood HTML at Step 02 is exempt (HTML files have `<title>` tag instead).
- **States implementation evidence REQUIRED (spec 053 — Step 15 only).** Every state declared in the sitemap entry's `states[]` MUST have implementation evidence in the produced file set: `loading` → `<route>/loading.tsx` sibling exists; `error` → `<route>/error.tsx` sibling exists; `empty` → page-internal render branch (`if (items.length === 0) return <EmptyState …/>` OR `<EmptyState>` component referenced); `default` is always implicit (the page body). States listed in `deferred_states[]` (with reason) are skipped — DO NOT invent empty-state copy for a degenerate case the product doesn't have; instead, ask the parent to flip the state to `deferred_states`. Reason: dogfood-2 shipped `/estoque` declaring `[default, loading, empty, error]` but emitted only `default + loading` (no empty branch, no error sibling). The acceptance criterion is mechanical-checkable: every declared state has a visible code surface.
- **Biome anti-pattern checklist — DO NOT VIOLATE (spec 053 — Step 15 only).** These shapes break the fork's `biome.json` (a11y / correctness rules) and force the founder to relax the config to unblock the build. Sub-agent self-check before DONE — none of these should appear in the produced file:
  - `key={i}` from `.map((_, i) =>` or `.map((item, i) =>` — use a stable id from the data OR a derived stable string. Skeleton-loading lists are the recurring offender; use `key={\`skeleton-${i}\`}` only if data has no usable id AND skeleton is throwaway.
  - `<div role="status">`, `<div role="article">`, `<div role="region">` — use semantic HTML: `<output>` (for status/live messages), `<article>`, `<section>`. Biome's `useSemanticElements` rule fires on these.
  - `dangerouslySetInnerHTML={…}` — never. Render Markdown via a sanitized renderer or render the structured content directly.
  - `<button>` without explicit `type="button"` (or `type="submit"`/`type="reset"`) — Biome's `useButtonType` rule fires. Default browser `type` is `submit` which submits the nearest form unintentionally.
  - `<img>` without `alt={…}` — use empty string `alt=""` for decorative images (signals "decorative" to screen readers); never omit the attribute entirely.

  Inline here on purpose — these shapes are React/Next-specific and don't belong in a generic `.claude/rules/` rule that propagates to non-JS forks. (Extract-if-reused decision deferred: not reused outside this brief.)
- **Primary metric prominence — render as MetricTile/hero, NOT badge (spec 053 — Step 15 only).** If the sitemap entry declares `primary_metric: "<label>"`, the value MUST render at hero-level: full-width MetricTile (per `<out>/docs/design-system/components.md`), large-numeric tile in a metrics grid row, OR a dashboard-card sized component. It MUST NOT render as a small badge in a page corner or a sub-line in a header. Reason: dogfood-2 shipped `/vendas` with "Caixa atual R$ 1.450,00" as a 12px top-right badge despite being the route's load-bearing value the user comes to check. If the route has no `primary_metric` field, ignore this constraint.
- **Glossary obligation — replace `### We don't say` terms with `### We say` equivalents (spec 054 — Step 15 only).** Before declaring DONE, scan the produced `page.tsx` for every term listed in brand-book `## Glossary § We don't say`. For each match, replace with the row's `Replacement` value UNLESS the route's surface scope falls under the entry's `Applies to` exemption (e.g. an entry marked `applies_to: marketing, pricing` does NOT apply to `/settings/integrations`). Example from dogfood-2 (Vetro): brand-book declared `Most Popular | Mais escolhido | English in pt-BR product | marketing, pricing`; pricing page MUST render `Mais escolhido` (NOT `Most Popular`) on the pricing badge. Sub-agent self-check before DONE: for each glossary `We don't say` entry whose `applies_to` matches the route's chrome/category, `grep -L "<term>" <target>/page.tsx` MUST return the file (term absent). If `## Glossary` is empty, no constraint applies.
- **Next.js 16+ async params + `'use client'` separation (spec 051 — DO NOT VIOLATE).** Dynamic-route segments (`[id]`, `[slug]`) deliver `params` as `Promise<{...}>` that MUST be `await`ed. Awaiting a Promise can ONLY happen in a Server Component. Therefore: **`'use client'` MUST NOT appear at the top of an `async` page component.** Next.js explicitly blocks this combination — the runtime error is verbatim `<PageName> is an async Client Component. Only Server Components can be async at the moment. This error is often caused by accidentally adding 'use client' to a module that was originally written for the server.` Canonical pattern when the page needs client interactivity (useState/useEffect/event handlers/hooks):
  ```tsx
  // app/<route>/page.tsx  — Server Component, NO directive
  import { <Name>Client } from "./_<Name>Client";
  export default async function <Name>Page({ params }: { params: Promise<{ id: string }> }) {
    const { id } = await params;
    return <<Name>Client id={id} />;
  }
  ```
  ```tsx
  // app/<route>/_<Name>Client.tsx  — Client Component, owns hooks
  "use client";
  import { useState } from "react";
  export function <Name>Client({ id }: { id: string }) {
    const [state, setState] = useState(...);
    return (<div>...</div>);
  }
  ```
  If the page is purely presentational (no hooks, no state, no event handlers), it can stay a single Server Component and skip the split entirely. Sub-agent self-check before declaring DONE: `grep -l "'use client'" app/<route>/page.tsx` MUST return nothing if `page.tsx` is async.

DELIVERABLE: The target file at the path above; if mock-data.ts was added or extended, that too. If the canonical Server+Client split is applied, the sibling `_<Name>Client.tsx` file too.

DONE_WHEN: File exists at deliverable path; valid TypeScript (Step 15 — Phase-4-verified by tsc); declared states visibly implemented (sibling files for loading/error; render branch for empty; deferred_states skipped per sitemap); uses tokens via var() or Tailwind utility classes (NO hex/px violations); buttons have type attribute; **per-route `export const metadata: Metadata` is present** (Step 15 only, except for root `/`); **Biome anti-pattern checklist self-passes** (no `key={i}`, no `<div role="status|article|region">`, no `dangerouslySetInnerHTML`, no `<img>` without `alt`); **if `primary_metric` declared in sitemap entry, the value renders as MetricTile/hero (not a corner badge)**; **all user-facing copy matches brand-book `## Language` target_language and respects `## Glossary § We don't say` term replacements where applies_to scope hits**; **if dynamic-segment route, `page.tsx` is either a non-async pure Server Component OR an async Server Component (no `'use client'` at top) with the client interactivity split into a sibling `_<Name>Client.tsx`**.
```

### Expo stack

Same shape as Next.js brief above, with React Native components (View / Text / Pressable / TextInput / FlatList) instead of HTML; className via NativeWind for styling (NOT StyleSheet.create); target file path is `{{out}}/app{{path}}.tsx` (Expo router file convention, no `/page.tsx` suffix).

## Concurrency cap

Phase 1 Step 02 screen writers (lo-fi mood HTML) + Phase 4 Step 15 screen writers (hi-fi page.tsx): **MAX 5 concurrent `Agent` calls** each. If sitemap has >5 routes, queue rest and dispatch as earlier ones return.

**Cap=5 was proven non-OOM** on spec 034's 17-route dogfood (2026-05-17). Re-evaluate only if a Phase 4 dogfood with 12+ atlas screens surfaces context pressure.

## Failure handling

Per spec 045 (port of spec 036 Q4 resolution):

- **Step 01 BLOCKED** or **Step 15 BLOCKED** → ABORT the entire run (upstream-of-everything or final deliverable).
- **Step 07 BLOCKED** via schema enforcement → AUTO-RETRY with augmented brief naming missing required_categories. Up to 2 retries before falling through to user `iterate` at Phase 2 gate.
- **Any other step BLOCKED** → degrade gracefully: append `{step_label, reason, artifacts_partial}` to `.state.json.blocked_steps`; log to REPORT.md `## Blocked steps`; continue to next step.

Screen-writer (per-route) failures within a single step (02/15): mark the specific route as BLOCKED in `.state.json`; continue with remaining routes. The whole step does NOT fail on one bad screen.

## Cross-references

- `pipeline-coverage.md` — phase/step map + size targets per step (15 steps v3)
- `state-machine.md` — `.state.json` v3 shape + gate semantics + resume support
- `sitemap-schema.md` — Step 07's load-bearing required_categories enforcement
- `quality-checklist.md` — per-step gate criteria the skill checks before declaring complete
- `SKILL.md` — orchestration body that dispatches these briefs
- `.claude/rules/delegation.md` — 5-field handoff discipline
- `templates/pipeline/<step>/prompt.md` — canonical step brief (sub-agents read this directly)
- `docs/specs/045-prototype-skill-pipeline-realign/` — spec source
- `docs/specs/032-pipeline-industry-alignment/` — parent industry-alignment (17 decisions ported here)
