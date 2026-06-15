#!/usr/bin/env bash
# 02-ui-impact-detect — surface classification (unchanged logic, spec 206 reframe).
source "$(dirname "$0")/_lib.sh"
echo "02-ui-impact-detect (rendered-surface classification)"

# --- rendered surfaces are detected -------------------------------------
for p in \
  "src/components/Button.tsx" \
  "app/dashboard/page.tsx" \
  "resources/views/home.blade.php" \
  "styles/theme.css" \
  "ui/Modal.vue" \
  "src/routes/login.svelte" \
  "assets/main.scss"; do
  out="$(printf '%s\n' "$p" | "$DETECT")"
  assert_not_contains "$out" "surfaces: (none)" "surface detected: $p"
done

# --- non-UI paths are NOT surfaces --------------------------------------
for p in \
  "docs/specs/206/spec.md" \
  "README.md" \
  ".agent0/tools/foo.sh" \
  "internal/server/handler.go" \
  "app/Http/Controllers/UserController.php" \
  "migrations/0001_init.sql" \
  "tests/unit/foo.test.ts" \
  "package.json"; do
  out="$(printf '%s\n' "$p" | "$DETECT")"
  assert_contains "$out" "surfaces: (none)" "non-UI not a surface: $p"
done

# --- legacy tier values accepted as `ui` (no crash), still reports surface
out="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared flow)"
assert_not_contains "$out" "surfaces: (none)" "legacy --declared flow still reports the surface"
out="$(printf '%s\n' "src/components/Button.tsx" | "$DETECT" --declared ui)"
assert_not_contains "$out" "surfaces: (none)" "--declared ui reports the surface"

# --- detector exits 0 (reports, never gates) ----------------------------
printf '%s\n' "src/components/Button.tsx" | "$DETECT" >/dev/null
assert_rc "$?" "0" "detector exits 0"

# --- mixed set: one surface among many non-UI is still found ------------
out="$(printf '%s\n' "README.md" "internal/x.go" "src/pages/Home.jsx" | "$DETECT")"
assert_not_contains "$out" "surfaces: (none)" "a single surface in a mixed diff is found"

finish
