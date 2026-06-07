#!/usr/bin/env bash
# 03-contract-tiers — verify-contract render/interaction/flow orchestration
# (spec 155 D3), driven by the FAKE agent-browser stub (offline, deterministic).
source "$(dirname "$0")/_lib.sh"
echo "03-contract-tiers (verify-contract tier orchestration)"

FAKE="$(fake_bin)"
export AB_CALLS_LOG="$WORK/ab-calls.log"

# A single static snapshot that satisfies every happy-path role/name across the
# three tiers, plus a url that matches both flow steps' expect_url regexes. The
# `button:Nonexistent` / `alert:never` targets are deliberately ABSENT so the
# flaky interaction step fails → must be recorded as a non-fatal warn.
cat > "$WORK/snapshot.json" <<'JSON'
{ "data": {
  "url": "http://localhost:3000/dashboard?from=/login",
  "refs": {
    "h1": {"role":"heading","name":"Dashboard"},
    "nav1": {"role":"navigation","name":"primary"},
    "b1": {"role":"button","name":"Create project"},
    "d1": {"role":"dialog","name":"New project"},
    "t1": {"role":"textbox","name":"Project name"},
    "s1": {"role":"button","name":"Save"},
    "hl": {"role":"heading","name":"Login"},
    "si": {"role":"button","name":"Sign in"}
  }
} }
JSON

run_contract() { # <fixture> <outdir-name>
  : > "$AB_CALLS_LOG"
  local out="$WORK/$2"
  AGENT0_BROWSER_BIN="$FAKE" bash "$BROWSER_TOOL" verify-contract \
    "http://localhost:3000/" "$FIXTURES/$1" "$out" >"$WORK/$2.log" 2>&1
  echo "$?"
}

# --- render tier (backward compatible) -----------------------------------
rc="$(run_contract render-only.json out-render)"
assert_rc "$rc" "0" "render-only contract passes"
rep="$WORK/out-render/report.json"
assert_eq "$(jq -r .overall "$rep")" "pass" "render overall pass"
assert_eq "$(jq -r '[.checks[] | select(.name|startswith("required:"))] | length' "$rep")" "2" "two required checks"
assert_contains "$(jq -r '.checks[].name' "$rep")" "console-errors" "console check present"
assert_contains "$(jq -r '.checks[].name' "$rep")" "screenshot" "screenshot check present"

# --- interaction tier ----------------------------------------------------
rc="$(run_contract with-interactions.json out-int)"
rep="$WORK/out-int/report.json"
assert_rc "$rc" "0" "interaction contract passes (flaky step does not fail it)"
assert_eq "$(jq -r .overall "$rep")" "pass" "interaction overall pass despite flaky miss"
# act verbs were driven, in order
assert_contains "$(cat "$AB_CALLS_LOG")" "click" "click verb invoked"
assert_contains "$(cat "$AB_CALLS_LOG")" "type" "type verb invoked"
first_click="$(grep -n '^click ' "$AB_CALLS_LOG" | head -n1 | cut -d: -f1)"
first_close="$(grep -n '^close ' "$AB_CALLS_LOG" | head -n1 | cut -d: -f1)"
if [ -n "$first_click" ] && [ -n "$first_close" ] && [ "$first_close" -gt "$first_click" ]; then
  PASS=$((PASS+1)); echo "  ✓ browser stays open through interaction steps"
else
  FAIL=$((FAIL+1)); echo "  ✗ browser closed before interaction steps"
fi
# the two real interaction steps asserted their post-state
assert_eq "$(jq -r '[.checks[] | select(.name|startswith("interaction:"))] | length' "$rep")" "3" "three interaction checks recorded"
# the flaky failing step is a warn, not a fail
assert_eq "$(jq -r '[.checks[] | select(.warn==true)] | length' "$rep")" "1" "flaky miss recorded as warn"
assert_eq "$(jq -r '[.checks[] | select(.ok==false and .warn==false)] | length' "$rep")" "0" "no fatal failures"

# --- flow tier -----------------------------------------------------------
rc="$(run_contract with-flow.json out-flow)"
rep="$WORK/out-flow/report.json"
assert_rc "$rc" "0" "flow contract passes"
assert_eq "$(jq -r .overall "$rep")" "pass" "flow overall pass"
assert_eq "$(jq -r '[.checks[] | select(.name|startswith("flow:"))] | length' "$rep")" "2" "two flow steps recorded"
assert_contains "$(cat "$AB_CALLS_LOG")" "open http://localhost:3000/login" "flow goto navigated"

# Same-step goto+action must resolve the target from the post-goto snapshot, not
# from the previous page. This catches a false green where one static snapshot
# accidentally satisfies every route.
dyn_bin_dir="$WORK/dyn-bin"; mkdir -p "$dyn_bin_dir"
cat > "$dyn_bin_dir/agent-browser" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "${AB_CALLS_LOG:-/dev/null}"
page_file="${VC_DYNAMIC_PAGE:?}"
[ -f "$page_file" ] || printf 'root' > "$page_file"
page="$(cat "$page_file")"
case "$1" in --version) echo "agent-browser 0.27.1"; exit 0 ;; esac
verb=""; for a in "$@"; do case "$a" in --*) ;; *) verb="$a"; break;; esac; done
case "$verb" in
  open)
    case "${2:-}" in */login*) printf 'login' > "$page_file" ;; *) printf 'root' > "$page_file" ;; esac ;;
  click)
    [ "$page" = "login" ] && [ "${2:-}" = "si" ] && printf 'dashboard' > "$page_file" ;;
  snapshot)
    page="$(cat "$page_file")"
    case "$page" in
      login) echo '{"data":{"url":"http://localhost:3000/login","refs":{"hl":{"role":"heading","name":"Login"},"si":{"role":"button","name":"Sign in"}}}}' ;;
      dashboard) echo '{"data":{"url":"http://localhost:3000/dashboard","refs":{"hd":{"role":"heading","name":"Dashboard"}}}}' ;;
      *) echo '{"data":{"url":"http://localhost:3000/","refs":{"home":{"role":"heading","name":"Home"}}}}' ;;
    esac ;;
  console) echo '{"data":{"messages":[]}}' ;;
  vitals) echo '{"data":{}}' ;;
  screenshot|screen)
    for a in "$@"; do case "$a" in --*|screenshot|screen) ;; *) printf 'PNG' > "$a" 2>/dev/null; break;; esac; done ;;
  close) : ;;
  *) : ;;
esac
exit 0
STUB
chmod +x "$dyn_bin_dir/agent-browser"
cat > "$WORK/goto-action-flow.json" <<'JSON'
{
  "required": [ { "role": "heading", "name": "Home" } ],
  "max_console_errors": 0,
  "flow": [
    { "goto": "http://localhost:3000/login",
      "action": "click", "target": { "role": "button", "name": "Sign in" },
      "expect_url": "/dashboard", "expect": { "role": "heading", "name": "Dashboard" } }
  ]
}
JSON
: > "$AB_CALLS_LOG"
printf 'root' > "$WORK/dyn-page"
VC_DYNAMIC_PAGE="$WORK/dyn-page" AGENT0_BROWSER_BIN="$dyn_bin_dir/agent-browser" \
  bash "$BROWSER_TOOL" verify-contract "http://localhost:3000/" "$WORK/goto-action-flow.json" "$WORK/out-dyn" >"$WORK/out-dyn.log" 2>&1
rc=$?
assert_rc "$rc" "0" "flow same-step goto+action passes with refreshed snapshot"
assert_contains "$(cat "$AB_CALLS_LOG")" "click si" "flow action resolved target after goto"

# --- malformed fixture → usage error (exit 3) ----------------------------
rc="$(run_contract malformed.json out-bad)"
assert_rc "$rc" "3" "malformed fixture → exit 3"
[ -f "$WORK/out-bad/report.json" ] && { FAIL=$((FAIL+1)); echo "  ✗ malformed must not write a report"; } || { PASS=$((PASS+1)); echo "  ✓ malformed writes no report"; }

# --- agent-browser unavailable ≠ pass (fail-closed, spec 152/153) --------
out="$WORK/out-unavail"
AGENT0_BROWSER_BIN="/nonexistent/agent-browser" bash "$BROWSER_TOOL" verify-contract \
  "http://localhost:3000/" "$FIXTURES/render-only.json" "$out" >/dev/null 2>&1
rc=$?
assert_rc "$rc" "4" "unavailable binary → exit 4 (never a pass)"
if [ -f "$out/report.json" ]; then
  assert_not_contains "$(jq -r .overall "$out/report.json")" "pass" "unavailable never reports pass"
else
  PASS=$((PASS+1)); echo "  ✓ unavailable writes no report (not a pass)"
fi

# --- live dogfood (skip-with-pass when no browser) -----------------------
if need_live; then
  echo "  ⓘ live mode available — (smoke only; logic covered above)"
fi

finish
