# Post-launch maintenance loop provider map

Copy this file into a consumer project and fill it with project-local choices. Do not commit real credentials, telemetry payloads, customer data, DSNs, API keys, or provider tokens.

## Loop owner

- **Human owner:** REPLACE_WITH_PERSON_OR_ROLE
- **Review owner:** REPLACE_WITH_PERSON_OR_ROLE
- **Release owner:** REPLACE_WITH_PERSON_OR_ROLE
- **Escalation path:** REPLACE_WITH_ON_CALL_OR_INCIDENT_PROCESS

## Capability roles

| Role | Chosen provider or process | Notes |
| --- | --- | --- |
| Signal source | REPLACE_WITH_ERROR_TRACKER_LOGS_ALERTS_OR_SUPPORT_QUEUE | Where production evidence originates. |
| Work hub | REPLACE_WITH_LINEAR_GITHUB_ISSUES_JIRA_OR_OTHER | Where the human-trackable item lives. |
| Agent delegate | REPLACE_WITH_CODEX_CLAUDE_CURSOR_DEVIN_OR_OTHER | The agent that may investigate or propose a fix. |
| Review gate | REPLACE_WITH_PR_REVIEW_AND_VALIDATION_PROCESS | Human-owned checkpoint before merge/release. |
| Feedback sink | REPLACE_WITH_TEST_SDD_MEMORY_REMINDER_ROUTINE_OR_PRODUCT_VN | Durable learning destination. |

## Token and credential classes

| Integration | Credential class | Storage location | Rotation owner | Notes |
| --- | --- | --- | --- | --- |
| Signal source | REPLACE_WITH_CLASS | REPLACE_WITH_SECRET_MANAGER_OR_LOCAL_CONFIG | REPLACE_WITH_OWNER | Do not put credentials in Agent0 templates. |
| Work hub | REPLACE_WITH_CLASS | REPLACE_WITH_SECRET_MANAGER_OR_LOCAL_CONFIG | REPLACE_WITH_OWNER | Prefer least-privilege scopes. |
| Agent delegate | REPLACE_WITH_CLASS | REPLACE_WITH_SECRET_MANAGER_OR_LOCAL_CONFIG | REPLACE_WITH_OWNER | Keep repo permissions narrow. |
| Repository host | REPLACE_WITH_CLASS | REPLACE_WITH_SECRET_MANAGER_OR_LOCAL_CONFIG | REPLACE_WITH_OWNER | Prefer branch/PR output, not direct writes to protected branches. |

## Data classes sent across the loop

| Data class | Can enter work hub? | Can enter agent prompt? | Redaction/minimization rule |
| --- | --- | --- | --- |
| Exception type/name | yes/no | yes/no | REPLACE_WITH_RULE |
| Stack trace | yes/no | yes/no | REPLACE_WITH_RULE |
| Log lines | yes/no | yes/no | REPLACE_WITH_RULE |
| Request URL/path | yes/no | yes/no | REPLACE_WITH_RULE |
| Headers/cookies/tokens | no | no | Strip before creating the item. |
| PII/customer data | yes/no | yes/no | REPLACE_WITH_RULE |
| Replay/session text | yes/no | yes/no | REPLACE_WITH_RULE |
| Payment/health/minor-related data | yes/no | yes/no | REPLACE_WITH_RULE |

## Trigger filters

- **Minimum severity:** REPLACE_WITH_SEVERITY_OR_MANUAL_ONLY
- **Minimum frequency:** REPLACE_WITH_THRESHOLD_OR_MANUAL_ONLY
- **Duplicate suppression:** REPLACE_WITH_DEDUPE_RULE
- **Rate limit/batching:** REPLACE_WITH_RATE_LIMIT
- **Manual dry-run period:** REPLACE_WITH_DURATION_OR_CONDITION

## Automation posture

- [ ] Manual intake works before automation is enabled.
- [ ] Dry-run produces work items without agent delegation.
- [ ] Automated issue creation has filters/rate limits.
- [ ] Automated agent delegation is off until a human approves the first fixture run.
- [ ] Auto-merge, auto-deploy, auto-rollback, and auto-close are disabled.

## Feedback sink routing

| Signal found during review | Route |
| --- | --- |
| Missing regression coverage | Add a test in the same fix diff. |
| Non-trivial hardening/refactor | Create an SDD spec. |
| Factual project lesson | Add project memory. |
| Deferred one-shot follow-up | Add a reminder. |
| Recurring operational check | Add a routine. |
| Product direction changed | Human explicitly starts product vN discovery. |
