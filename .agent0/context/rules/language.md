# Language

Durable project language and locale guidance belongs in `.agent0/project-core.md` when that file exists. It is mirrored into both runtime entrypoints through the `AGENT0:PROJECT` region, so read it before falling back to this rule.

Agent0's own fallback:

- Human communication follows the user's language; use pt-BR when the user writes in Portuguese.
- Repository artifacts default to English: harness docs, rules, specs, skills, tool docs, code comments, and commits.
- Existing files keep their surrounding language unless the task is translation/localization.
- Consumer projects own their own `.agent0/project-core.md`; do not infer a consumer project's language policy from Agent0.

Consumer setup: start from `.agent0/project-core.md.example`, copy it to `.agent0/project-core.md`, replace the placeholders, then run `.agent0/tools/project-core-sync.sh --apply` in that consumer to render the local mirrors. A later `sync-harness.sh --apply` also calls the same local renderer, but upstream harness sync is not required just to refresh project-core mirrors.

Until that source exists, Agent0 surfaces a `bootstrap-advisory` / `=== bootstrap ===` reminder in sync, startup, status, and doctor. After `.agent0/project-core.md` is configured and the local renderer runs, those reminders must stop; repeated language/bootstrap alerts after configuration are false positives.

The example carries an acknowledgement marker:

```markdown
<!-- AGENT0:PROJECT-CORE-TEMPLATE: <id> -->
```

When Agent0 updates the template id, configured consumers keep their real `.agent0/project-core.md` untouched but receive a `project-core-advisory` / `=== project-core ===` review reminder until the source is reviewed and its marker is updated to the current example id. Do not silence this by editing the rendered entrypoint regions; update the source and rerun `.agent0/tools/project-core-sync.sh --apply`.
