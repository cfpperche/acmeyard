#!/usr/bin/env bash
# .agent0/tools/lib/paid-media.sh — PAID-MEDIA sub-kit for Agent0 capacity tools. Spec 164.
#
# Companion to lib/capacity.sh (the neutral local/free+paid kernel). This lib holds
# the PAID-DOMAIN plumbing that was duplicated across the paid tools (sound,
# audio --remote): the *-tiers.yaml scalar oracle reader + leak-safe FAL_KEY state.
# Sourced by the paid tools so the paid concerns live + are tested once. A separate
# file (not folded into capacity.sh) on cohesion grounds — capacity.sh's identity is
# "no cost, no key, stays local"; FAL_KEY + a tiers oracle are paid-domain. Decided
# in a decision-grade /meeting (claude+codex, blind openings converged independently;
# .agent0/meetings/paid-media-kit-honest-scope-2026-06-07T01-33-04Z/).
#
# DELIBERATE NON-GOALS (kill-gate measurement — these are genuine per-tool variants,
# NOT one mechanism; extracting them would change behavior):
#   - cost FORMULA (per-second / per-1k-char / table / per-second) — stays local
#   - the --confirm-cost-usd GATE (sound hybrid-threshold vs video hard vs none) — policy, local
#   - fal invocation (sync run vs async submit; per-model body) — already at fal-rest.sh
#   - a FAL_KEY *require* helper — failure contracts diverge (sound compact cap_fail vs
#     audio local pretty fail), so a helper that fails internally can't serve both
#
# CONTRACT: every helper here is PURE — it NEVER prints a status line and NEVER calls
# exit. It returns a value (stdout) or a status code; the calling tool keeps its own
# failure path. (This is what lets one lib serve tools with divergent fail contracts.)
# FAL_KEY is never echoed — the state helper emits only the literal `set`/`unset`.
#
# Propagated to consumers via the .agent0/tools/lib|*.sh sync glob (added in spec 163).
# Behavior is byte-identical to the per-tool copies it replaces — proven by the golden
# parity gate (.agent0/tests/capacity-kit/golden.sh + paid-golden.sh).

# --- tiers.yaml scalar oracle (no yq dependency; fixed 2-/4-space block scan) ----
# Top-level scalar: $1=file $2=key -> value (surrounding quotes stripped). = sound ytop.
pm_yaml_top() { awk -v f="$2:" '$1==f{v=$2; gsub(/^"|"$/,"",v); print v; exit}' "$1"; }

# Per-tier block scalar: $1=file $2=tier $3=field -> value (leading ws + trailing
# `# comment` + surrounding quotes + trailing ws all stripped). = sound yget, verbatim
# logic. Scans the `  <tier>:` block; exits at the next 2-space key. Quote/comment
# stripping is load-bearing (e.g. sound-tiers.yaml carries inline comments).
pm_yaml_tier_field() {  # $1=file $2=tier $3=field
  awk -v t="  $2:" -v f="$3:" '
    $0==t {inb=1; next}
    inb && /^  [^ ]/ {exit}
    inb {
      line=$0; sub(/^[ \t]+/,"",line)
      if (index(line, f)==1) {
        val=substr(line, length(f)+1)
        sub(/^[ \t]+/,"",val); sub(/[ \t]+#.*$/,"",val)
        gsub(/^"|"$/,"",val); sub(/[ \t]+$/,"",val)
        print val; exit
      }
    }' "$1"
}

# --- FAL_KEY state (leak-safe; never echoes the value) ------------------------
# Predicate: success iff FAL_KEY is set+non-empty. The tool decides how to fail.
pm_has_fal_key() { [ -n "${FAL_KEY:-}" ]; }
# State string for caps/doctor: emits the literal `set` or `unset`, never the key.
pm_fal_key_state() { [ -n "${FAL_KEY:-}" ] && echo set || echo unset; }
