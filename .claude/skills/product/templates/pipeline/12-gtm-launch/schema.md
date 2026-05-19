# Step 12 — GTM-launch schema

## Output file

`<out>/docs/gtm-launch.md`

## Size targets

- **Floor:** 4 KB (less means canvas is too thin OR launch plan misses weeks)
- **Ceiling:** 7 KB hard (more means falling into full launch playbook — post-PMF concern; trim to standard tier)

## Required H2 sections (in order)

1. `## Positioning Canvas`
2. `## Launch Plan`
3. `## Pricing Strategy`
4. `## Open Decisions`

## Positioning Canvas — 5 lines required

```
**For:** <target customer>
**Who:** <problem statement, user voice>
**We are:** <category> that <differentiator>
**Unlike:** <primary alternative>
**Our product:** <value vs alternative>
```

All 5 lines required. Missing line = sub-agent re-emit.

## Launch Plan — 4 weeks required

Each week:
- 1-3 deliverables (concrete artifacts)
- 1 measurement line (what we observe)
- User-flow shaped title (NOT generic labels like "Outreach")

## Pricing Strategy

Either tier table (free/standard/pro shape if relevant) OR explicit "no tiers v1 — single price $X/mo". Pricing model declaration required: `flat-rate | usage-based | per-seat | freemium | trial`.

## Open Decisions

Table: Decision | Default | Flip if. 2-4 rows minimum.

## Compliance discipline

Refuse claims like:
- "GDPR-compliant" → use "designed for GDPR"
- "SOC 2 certified" → use "SOC 2 readiness in progress"
- "HIPAA-compliant" → use "HIPAA-eligible architecture"

Unless Step 09 legal posture confirms those certifications are actually in place at launch.

## Validation rules (parent-side)

1. All 4 H2 sections present
2. Positioning Canvas has 5 lines
3. Launch Plan has exactly 4 weeks
4. Each week has 1-3 deliverables + 1 measurement
5. Pricing Strategy declares tier shape OR single-price
6. Open Decisions has 2-4 rows
7. File size 4-7 KB

## Cross-references

- `prompt.md` — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 12
