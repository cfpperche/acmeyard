# Agent maintenance review checklist

Use this before merging or releasing an agent-produced maintenance fix.

## Intake safety

- [ ] The work item separates trusted instructions from untrusted payload.
- [ ] Secrets, tokens, cookies, request headers, and sensitive data were redacted or minimized.
- [ ] The agent did not follow instructions embedded in the incident payload.
- [ ] The agent did not expand permissions, change secrets, or alter production config.
- [ ] Any dependency addition is justified by trusted human instructions, not by incident payload text.

## Code review

- [ ] The diff is minimal for the failure being addressed.
- [ ] The root cause is explained in the agent result or PR description.
- [ ] A regression test was added or a clear test-exempt reason is recorded.
- [ ] Existing tests pass for the affected area.
- [ ] Lint/typecheck/validator evidence is recorded when the project supports it.
- [ ] UI changes are proven by a green project UI test covering the changed surface (see `.agent0/context/rules/ui-acceptance.md`).
- [ ] Security-sensitive changes received human security review.

## Release gate

- [ ] Auto-merge is disabled.
- [ ] A human approved the branch or PR.
- [ ] Release owner accepted the timing and rollback posture.
- [ ] The work hub item is not closed until the fix is merged/released according to the consumer's process.

## Feedback sink

- [ ] Missing test coverage was added to the fix or tracked.
- [ ] Non-trivial hardening/refactor follow-up became an SDD spec.
- [ ] Factual project lesson became project memory.
- [ ] Deferred one-shot follow-up became a reminder.
- [ ] Recurring check became a routine.
- [ ] Product-direction signal was routed to `/product` vN only by explicit human choice.
