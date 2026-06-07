# Reference research — mandatory and artifacted

A design pass without references is decoration, not design. Every `create` / `refine` / `explore` pass researches references **before** setting direction, and records them in a git-tracked `reference-research.md` (template in `templates/`). The rejected patterns matter as much as the borrowed ones — that's where taste is legible.

## The three free mechanisms (local + remote)

1. **Web search / fetch.** Domain-specific UI patterns, platform conventions (HIG / Material / web platform), accessibility norms (WCAG, ARIA authoring practices), and current setup docs for the resolved stack. Cite every URL in the `Sources` block.
2. **`agent-browser.sh` — visit & screenshot real exemplars.**
   ```bash
   bash .agent0/tools/agent-browser.sh run -- open "https://example.com/dashboard"
   bash .agent0/tools/agent-browser.sh run -- screenshot "<gitignored-evidence-dir>/ref-1.png"
   bash .agent0/tools/agent-browser.sh run -- snapshot --json   # a11y/DOM structure of the exemplar
   ```
   Screenshots are **gitignored runtime evidence**, linked from `reference-research.md`, never committed.
3. **Repo scan (`rg`).** Existing tokens, components, Storybook stories, routes, brand docs, `/product` artifacts, and prior specs — so the design builds on what's there.
   ```bash
   rg -l "tailwind|tokens|theme|@radix|shadcn" <project>
   rg --files <project> | rg -i "design-system|brand|components|stories"
   ```

## The artifact contract (one compact pair per surface)

`reference-research.md` rows each carry: **source (URL/path) · domain relevance · pattern borrowed · pattern rejected · implementation consequence.** "Implementation consequence" is the bridge to code — it says what the borrowed pattern *means* for this build (a token, a layout decision, a component choice). A row with no consequence is just a bookmark.

The companion `design-direction.md` turns the research into a decision: tokens (reused or proposed), the feel, the surfaces, and the done-proof. See SKILL.md § Artifacts & locations for where the pair lives.

## Honesty

Research is real or it isn't. Don't fabricate references or invent URLs. If `agent-browser` is unavailable, web + repo research still apply, and the reference doc says capture was unavailable — it does not pretend screenshots exist.
