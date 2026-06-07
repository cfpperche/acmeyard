#!/usr/bin/env bash
# 01-detect — ui-impact-detect.sh classification + mismatch flag (spec 155 D2).
source "$(dirname "$0")/_lib.sh"
echo "01-detect (UI-impact detection heuristic)"

# --- rendered surfaces are flagged ---------------------------------------
for p in \
  "src/components/Button.tsx" \
  "app/dashboard/page.tsx" \
  "resources/views/home.blade.php" \
  "styles/theme.css" \
  "ui/Modal.vue" \
  "src/routes/login.svelte" \
  "assets/main.scss"; do
  out="$(printf '%s\n' "$p" | "$DETECT" --declared none)"
  assert_contains "$out" "mismatch: true" "surface flagged: $p"
done

# --- non-UI paths are NOT flagged ----------------------------------------
for p in \
  "docs/specs/155/spec.md" \
  "README.md" \
  ".agent0/tools/foo.sh" \
  "internal/server/handler.go" \
  "app/Http/Controllers/UserController.php" \
  "migrations/0001_init.sql" \
  "tests/unit/foo.test.ts" \
  "package.json"; do
  out="$(printf '%s\n' "$p" | "$DETECT" --declared none)"
  assert_contains "$out" "mismatch: false" "non-UI not flagged: $p"
done

# --- declaration-first: a declared depth clears the mismatch -------------
out="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared render)"
assert_contains "$out" "mismatch: false" "declared render clears mismatch on a surface"
out="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared flow)"
assert_contains "$out" "mismatch: false" "declared flow clears mismatch on a surface"

# --- suggested floor is render on any surface, none otherwise ------------
out="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared none)"
assert_contains "$out" "suggested: render" "suggested floor is render on a surface"
out="$(printf '%s\n' "internal/server/handler.go" | "$DETECT" --declared none)"
assert_contains "$out" "suggested: none" "suggested is none on a non-UI change"

# --- the detector SUGGESTS, never sets (advisory exit 0) -----------------
printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared none >/dev/null
assert_rc "$?" "0" "detector exits 0 (reports, never gates)"

# --- JSON shape ----------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  j="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared none --json)"
  assert_eq "$(printf '%s' "$j" | jq -r .mismatch)" "true" "json mismatch true"
  assert_eq "$(printf '%s' "$j" | jq -r .suggested)" "render" "json suggested render"
  assert_eq "$(printf '%s' "$j" | jq -r '.surfaces | length')" "1" "json surfaces has the one path"
fi

# --- mixed set: one surface among many non-UI still flags ----------------
out="$(printf '%s\n' "README.md" "internal/x.go" "src/pages/Home.jsx" | "$DETECT" --declared none)"
assert_contains "$out" "mismatch: true" "a single surface in a mixed diff flags"

finish
