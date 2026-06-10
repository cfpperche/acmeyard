# Squad

`/squad` is Agent0's **autonomous, symmetric, ping-pong multi-agent build loop**: two heterogeneous runtimes (Claude Code ↔ Codex CLI today; the name is N-ready) implement one already-`/sdd plan`-ned spec together, taking turns *without a human pumping each turn*, until an **externally-verified done-condition** is met — then the human approves and triggers production. It is the autonomous build loop whose prerequisite is the de-biased deliberation capacity that makes "the agents agree" trustworthy.

## The load-bearing invariant

**Done is defined by reality external to the agents, never by their agreement.** Agent agreement only sets `propose-done`; the external `gate` (the `squad.json` commands — tests/build/validator green) is the only thing that reaches `ready_for_human_prod`. This is enforced mechanically in `squad.sh` and is *why* the de-biased deliberation capacity is a hard predecessor: two models converging is a social signal, not evidence the product works.

## Shape

- **State machine:** `.agent0/skills/squad/scripts/squad.sh` owns the mechanical, safety-critical state (run dir under `.agent0/.runtime-state/squads/`, turn-lock, budget, gate runner, terminal states, write-guard, rollback). The **runtime owns the loop** (the pump in `SKILL.md`) — same split as `meeting.sh` (state) ↔ runtime (content).
- **Gate contract:** `docs/specs/<NNN-slug>/squad.json` (see the skill's `references/squad-contract.md`).
- **Symmetric initiation:** whoever runs `/squad` owns the loop and drives the peer via `codex-exec` / `claude-exec` (workspace-write). No runtime is privileged.
- **Target must contain the harness:** the exec bridges anchor `ROOT` to the harness root and refuse a `--cwd` outside it, so `/squad`'s peer-driving only works inside a repo that has the Agent0 harness (Agent0 itself, or a consumer with it synced) — never an external/`/tmp` repo. (Surfaced by the 150.1 live dogfood; `init` warns when the bridge scripts are absent.)
- **Peer-turn hygiene:** a bridge sub-invocation (`codex-exec`/`claude-exec`) is a bounded subprocess, not a handoff-owning session — both bridges set `CLAUDE_SKIP_SESSION_HOOKS=1` so the session-handoff Stop-hook nag does NOT fire mid-turn (otherwise the peer gets blocked into rewriting the orchestrator-owned, `forbidden_paths` `HANDOFF.md`). Recover from a false-positive/reconciled abort with **`squad.sh resume`** (non-destructive re-baseline; refuses a genuine forbidden touch without `--force`) rather than `rollback` (which discards uncommitted work). Author `forbidden_paths` with anchored patterns — a bare substring like `secrets` false-matches `secrets-scan.md`.

## The three flaws the design rejects (the bounded/gate-driven posture)

The maximalist "infinite, 100% AI, human only at the very end, convergence = the agents agreeing" framing fails on: (a) convergence ≠ correctness (mutual confirmation); (b) "infinite" = unbounded cost + drift; (c) "human only at the end" removes the human from the last-20% where agents are weakest, and autonomous-to-prod is the highest-risk surface. `/squad` therefore is:

- **Bounded** — `max_rounds` + `max_repair_attempts` (+ future token/spend ceilings); exhaustion circuit-breaks to `aborted_budget` / `aborted_repairs`.
- **Gate-driven** — the external `gate`, not agreement, closes the run.
- **Human-at-milestone-gates** — spec-approved up front, `human_checkpoint_required` at phase/risky boundaries, and **the human triggers production** (the squad prepares; it never deploys to prod). Autonomy is earned with evidence (rule-of-three), not assumed.
- **Write-serialized** — turn-locked single-writer on one tree for v1 (the `meeting.sh` invariant); out-of-turn changes → `aborted_conflict`. Worktree-per-agent + merge is v2.

## Relationship to other capacities

- **De-biased deliberation** — hard predecessor; `/squad` reuses its commit/reveal + claim/evidence ledger for any in-loop disagreement.
- **Meeting bounded-autopilot** — `/squad` is the autonomous-loop demand the meeting autopilot gate was gated on, realized as a *build* loop carrying that bounded/gate-driven discipline; the friction *measurement* stays, its autopilot-build concern is superseded by `/squad`.
- **`/product` + SDD** — `/squad` runs a spec the planning pipeline produced; it does not replace them.
- **governance-gate / secrets-scan** — unchanged floors; the squad's prod-trigger is human, and destructive/outward actions stay gated.

## Notes

_Consumer-extension surface — append consumer-local bullets here. Sync flags the file as `!! customized` (sha-compare is section-blind); the conflict region is mechanically this section: take new upstream verbatim, re-add consumer bullets at the end._
