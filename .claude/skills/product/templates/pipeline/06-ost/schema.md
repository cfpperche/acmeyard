# Step 06 — OST schema

## Output file

`<out>/docs/ost.md`

## Size targets

- **Floor:** 3 KB (less means tree is too thin or solutions are too shallow)
- **Ceiling:** 6 KB hard (more means OST is doing PRD's job — push to PRD § Backlog instead)

## Required structure

```markdown
# OST — <product name>

_OST shape per Teresa Torres, Continuous Discovery Habits (Product Talk Academy)._

## Desired Outcome

> <verbatim quote of PRD's NSM>

## Opportunities

(3-5 entries, each with provenance tag + 2-3 solutions each with status tag)
```

## Required attributes per node

| Node type | Required attributes |
|---|---|
| Desired Outcome | verbatim NSM quote (1 root only) |
| Opportunity | user-voice problem statement + provenance tag `[interview: <subject>]` OR `[inferred: <persona>]` |
| Solution | high-level approach (NOT implementation) + status tag `explored` / `to-test` / `parked` |

## Format choices

- **Nested markdown bullets** (default) — fastest write, easiest diff
- **Mermaid diagram** — when tree breadth ≥4 AND breadth/depth ratio favors visual

Sub-agent picks based on clarity at actual tree depth.

## Validation rules (parent-side, post-Step-06 return)

1. Exactly 1 Desired Outcome (single root)
2. 3-5 Opportunities (refuse if fewer than 3 OR more than 5)
3. 2-3 Solutions per Opportunity (refuse if 0 OR >3)
4. Every Opportunity has provenance tag
5. Every Solution has status tag
6. File size 3-6 KB (warn if outside range)

## Cross-references

- `prompt.md` — full sub-agent brief
- `.claude/skills/product/references/pipeline-coverage.md` § Step 06
