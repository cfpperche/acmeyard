#!/usr/bin/env bash
# 02-advisory — validator surfaces visual-contract advisory without gating.
source "$(dirname "$0")/_lib.sh"
echo "02-advisory (validator visual-contract advisory)"

make_repo() {
  local dir="$1"
  mkdir -p "$dir/bin"
  cat > "$dir/bin/npm" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$dir/bin/npm"

  (
    cd "$dir" || exit 1
    git init -q
    printf '{"scripts":{"test":"true"}}\n' > package.json
  )
}

run_validator_case() {
  local name="$1"
  local path="$2"
  local repo="$WORK/$name"
  local stdout_file="$WORK/$name.stdout"
  local stderr_file="$WORK/$name.stderr"
  local rc_file="$WORK/$name.rc"
  make_repo "$repo"
  mkdir -p "$repo/$(dirname "$path")"
  printf 'changed\n' > "$repo/$path"

  (
    cd "$repo" || exit 1
    PATH="$repo/bin:$PATH" "$VALIDATOR" >"$stdout_file" 2>"$stderr_file"
  )
  printf '%s' "$?" > "$rc_file"
  CASE_RC="$(cat "$rc_file")"
  CASE_STDOUT="$(cat "$stdout_file")"
  CASE_STDERR="$(cat "$stderr_file")"
}

run_validator_case ui_surface "components/Button.tsx"
assert_rc "$CASE_RC" "0" "surface-change validator exits 0"
assert_contains "$CASE_STDERR" "visual-contract-advisory:" "surface change emits visual-contract advisory"
if command -v jq >/dev/null 2>&1; then
  assert_eq "$(printf '%s' "$CASE_STDOUT" | jq -r .ok)" "true" "surface-change validator JSON remains ok:true"
fi

run_validator_case non_ui "internal/server/handler.go"
assert_rc "$CASE_RC" "0" "non-UI validator exits 0"
assert_not_contains "$CASE_STDERR" "visual-contract-advisory:" "non-UI change does not emit visual-contract advisory"
if command -v jq >/dev/null 2>&1; then
  assert_eq "$(printf '%s' "$CASE_STDOUT" | jq -r .ok)" "true" "non-UI validator JSON remains ok:true"
fi

run_declared_ui_case() {
  local name="$1"
  local with_report="$2"
  local repo="$WORK/$name"
  local stdout_file="$WORK/$name.stdout"
  local stderr_file="$WORK/$name.stderr"
  make_repo "$repo"
  mkdir -p "$repo/components" "$repo/docs/specs/001-ui" "$repo/artifacts/visual"
  printf 'changed\n' > "$repo/components/Button.tsx"
  cat > "$repo/docs/specs/001-ui/spec.md" <<'EOF'
# 001 — ui

**Status:** in-progress
**UI impact:** render
EOF
  if [ "$with_report" = "yes" ]; then
    printf '{"overall":"pass","checks":[]}\n' > "$repo/artifacts/visual/report.json"
  fi

  (
    cd "$repo" || exit 1
    PATH="$repo/bin:$PATH" "$VALIDATOR" >"$stdout_file" 2>"$stderr_file"
  )
  CASE_RC="$?"
  CASE_STDOUT="$(cat "$stdout_file")"
  CASE_STDERR="$(cat "$stderr_file")"
}

run_declared_ui_case declared_missing no
assert_rc "$CASE_RC" "0" "declared UI without report exits 0"
assert_contains "$CASE_STDERR" "declared UI impact 'render'" "declared UI without report emits evidence advisory"
if command -v jq >/dev/null 2>&1; then
  assert_eq "$(printf '%s' "$CASE_STDOUT" | jq -r .ok)" "true" "declared UI without report JSON remains ok:true"
fi

run_declared_ui_case declared_with_report yes
assert_rc "$CASE_RC" "0" "declared UI with passing report exits 0"
assert_not_contains "$CASE_STDERR" "declared UI impact 'render'" "passing report suppresses evidence advisory"
if command -v jq >/dev/null 2>&1; then
  assert_eq "$(printf '%s' "$CASE_STDOUT" | jq -r .ok)" "true" "declared UI with report JSON remains ok:true"
fi

finish
