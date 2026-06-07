#!/usr/bin/env bash
# Spec 156 — seed files (ship-once, never-reconcile). The OD-engine-regenerated
# files (od-catalog-index.json, vendor/open-design/.cache/ds-index.json,
# vendor/open-design/MANIFEST.json) are COPY_CHECK_SEED:
#   - absent in consumer        → seeded (cold-start preserved)
#   - present + drifted         → `= seed`, NOT `!! customized`; bytes untouched
#   - --force                   → still not overwritten
#   - already-baselined drifted → self-heals: no orphan refusal, baseline drops it
# NOTE: no `set -e` — --check/--apply legitimately exit 1 on drift; assertions
# track pass/fail manually.
set -uo pipefail

AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}"
TOOL="$AGENT0_ROOT/.agent0/tools/sync-harness.sh"

TMPDIR="$(mktemp -d -t spec-156-43-XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

SRC="$TMPDIR/agent0"
SEED_A=".claude/skills/product/references/od-catalog-index.json"
SEED_C=".claude/skills/product/vendor/open-design/MANIFEST.json"

mkdir -p "$SRC/$(dirname "$SEED_A")" "$SRC/$(dirname "$SEED_C")"

# --- Build SRC as a git work-tree (seeds must be tracked to be walked) ---
git -C "$SRC" init -q
printf '{"version":1,"snapshot_date":"2026-06-02","vendors":[]}\n' > "$SRC/$SEED_A"
printf '{"pinned_sha":"aaa","history":[{"event":"apply","at":"2026-06-02"}]}\n' > "$SRC/$SEED_C"
# a normal (non-seed) managed file so the manifest/baseline is non-empty
printf '# product skill\n' > "$SRC/.claude/skills/product/SKILL.md"
printf '{"hooks":{}}\n' > "$SRC/.claude/settings.json"
printf '# CLAUDE\n\n## Compact Instructions\n' > "$SRC/CLAUDE.md"
git -C "$SRC" add -A
git -C "$SRC" -c user.email=t@t -c user.name=t commit -q -m init

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✓ $1"; }
no()  { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# ===================================================================
# Scenario 1 (V2): cold consumer — seed is copied when absent
# ===================================================================
C1="$TMPDIR/cold"; mkdir -p "$C1"
OUT="$(bash "$TOOL" --agent0-path="$SRC" --apply "$C1" 2>&1)"
echo "$OUT" | grep -q "+ seeded $SEED_A" && ok "cold: catalog seeded" || no "cold: catalog NOT seeded"
[ -f "$C1/$SEED_A" ] && diff -q "$C1/$SEED_A" "$SRC/$SEED_A" >/dev/null && ok "cold: seeded bytes match source" || no "cold: seeded file missing/wrong"
echo "$OUT" | grep -q '[0-9]* seeded' && ok "cold: summary reports seeded count" || no "cold: summary lacks seeded"
# the seed must NOT appear in the written baseline
if [ -f "$C1/.agent0/harness-sync-baseline.json" ]; then
  jq -e --arg k "$SEED_A" '.files | has($k) | not' "$C1/.agent0/harness-sync-baseline.json" >/dev/null \
    && ok "cold: seed omitted from baseline" || no "cold: seed leaked into baseline"
else
  no "cold: no baseline written"
fi

# ===================================================================
# Scenario 2 (V1): present + drifted seed → `= seed`, never `!! customized`
# ===================================================================
C2="$TMPDIR/warm"; mkdir -p "$C2/$(dirname "$SEED_A")" "$C2/$(dirname "$SEED_C")"
printf '{"version":1,"snapshot_date":"2026-06-03","vendors":["DRIFTED"]}\n' > "$C2/$SEED_A"
printf '{"pinned_sha":"aaa","history":[{"event":"apply","at":"2026-06-03"}]}\n' > "$C2/$SEED_C"
DRIFTED_A_SHA="$(sha256sum "$C2/$SEED_A" | awk '{print $1}')"
OUTCHK="$(bash "$TOOL" --agent0-path="$SRC" --check "$C2" 2>&1)"
echo "$OUTCHK" | grep -q "= seed $SEED_A" && ok "warm: catalog reported = seed" || no "warm: catalog not = seed"
echo "$OUTCHK" | grep -q "= seed $SEED_C" && ok "warm: manifest reported = seed (all 3 paths recognized)" || no "warm: manifest not = seed"
echo "$OUTCHK" | grep -q "!! customized $SEED_A" && no "warm: catalog FALSELY customized" || ok "warm: catalog NOT flagged customized"
# apply must leave the consumer's drifted bytes untouched
bash "$TOOL" --agent0-path="$SRC" --apply "$C2" >/dev/null 2>&1
[ "$(sha256sum "$C2/$SEED_A" | awk '{print $1}')" = "$DRIFTED_A_SHA" ] && ok "warm: apply left drifted bytes untouched" || no "warm: apply mutated the seed"

# ===================================================================
# Scenario 3 (V4): --force must NOT overwrite a present seed
# ===================================================================
bash "$TOOL" --agent0-path="$SRC" --apply --force "$C2" >/dev/null 2>&1
[ "$(sha256sum "$C2/$SEED_A" | awk '{print $1}')" = "$DRIFTED_A_SHA" ] && ok "--force: seed still untouched" || no "--force: seed overwritten"

# ===================================================================
# Scenario 4 (V3): already-baselined drifted seed self-heals (no refusal,
# baseline entry dropped, consumer bytes preserved)
# ===================================================================
C3="$TMPDIR/baselined"; mkdir -p "$C3/$(dirname "$SEED_A")" "$C3/.agent0"
printf '{"version":1,"snapshot_date":"2026-06-03","vendors":["DRIFTED"]}\n' > "$C3/$SEED_A"
B3_SHA="$(sha256sum "$C3/$SEED_A" | awk '{print $1}')"
# seed the consumer's other managed file to a clean state so only the seed is interesting
mkdir -p "$C3/.claude/skills/product"; cp "$SRC/.claude/skills/product/SKILL.md" "$C3/.claude/skills/product/SKILL.md"
# write a baseline that STILL lists the seed path (the pre-156 stale entry)
cat > "$C3/.agent0/harness-sync-baseline.json" <<JSON
{ "agent0_commit": null, "synced_at": "2026-06-02T00:00:00Z", "tool_version": 1,
  "files": { "$SEED_A": "deadbeef", ".claude/skills/product/SKILL.md": "$(sha256sum "$SRC/.claude/skills/product/SKILL.md" | awk '{print $1}')" } }
JSON
OUT3="$(bash "$TOOL" --agent0-path="$SRC" --apply "$C3" 2>&1)"
echo "$OUT3" | grep -q "!! customized $SEED_A (upstream-removed)" && no "self-heal: seed wrongly refused as orphan" || ok "self-heal: no orphan refusal"
[ "$(sha256sum "$C3/$SEED_A" | awk '{print $1}')" = "$B3_SHA" ] && ok "self-heal: consumer bytes preserved" || no "self-heal: consumer copy mutated/deleted"
jq -e --arg k "$SEED_A" '.files | has($k) | not' "$C3/.agent0/harness-sync-baseline.json" >/dev/null \
  && ok "self-heal: stale baseline entry dropped" || no "self-heal: baseline still lists the seed"

echo "  [$PASS pass / $FAIL fail]"
[ "$FAIL" -eq 0 ]
