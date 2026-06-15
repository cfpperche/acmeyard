#!/usr/bin/env bash
# 01-runner-detect — ui-runner-detect.sh declarable-signal detection (spec 206).
source "$(dirname "$0")/_lib.sh"
echo "01-runner-detect (does the project declare a UI test runner?)"

mk() { mktemp -d -t uia-rd-XXXXXX; }

# --- absent: empty project ----------------------------------------------
r="$(mk)"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "1" "empty project → absent (exit 1)"

# --- present: package.json script keys ----------------------------------
for key in test:e2e e2e test:ui test:browser e2e:ci; do
  r="$(mk)"; printf '{"scripts":{"%s":"x"}}' "$key" > "$r/package.json"
  "$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "0" "package.json script '$key' → present"
done

# --- a non-UI script key does NOT count ---------------------------------
r="$(mk)"; printf '{"scripts":{"build":"x","test":"jest"}}' > "$r/package.json"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "1" "plain build/test script → absent"

# --- present: known config files ----------------------------------------
for cfg in playwright.config.ts cypress.config.js wdio.conf.ts nightwatch.conf.js; do
  r="$(mk)"; : > "$r/$cfg"
  "$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "0" "config '$cfg' → present"
done

# --- gaming: a config buried in node_modules is EXCLUDED -----------------
r="$(mk)"; mkdir -p "$r/node_modules/some-dep"; : > "$r/node_modules/some-dep/playwright.config.ts"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "1" "playwright.config in node_modules → absent"

# --- gaming: a vendored/extracted config is EXCLUDED --------------------
r="$(mk)"; mkdir -p "$r/vendor/x" "$r/extracted-abc/y"
: > "$r/vendor/x/cypress.config.js"; : > "$r/extracted-abc/y/playwright.config.ts"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "1" "vendored/extracted config → absent"

# --- present: stack-neutral override .agent0/ui-test.json ---------------
r="$(mk)"; mkdir -p "$r/.agent0"; printf '{"command":"pytest tests/e2e"}' > "$r/.agent0/ui-test.json"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "0" "override with command → present"
out="$("$RUNNER_DETECT" --root "$r" --json)"; assert_contains "$out" '"signal":"override:.agent0/ui-test.json"' "override json signal"

# --- override with EMPTY command does not count -------------------------
r="$(mk)"; mkdir -p "$r/.agent0"; printf '{"command":""}' > "$r/.agent0/ui-test.json"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "1" "override with empty command → absent"

# --- workspace package.json (nested) is found ---------------------------
r="$(mk)"; mkdir -p "$r/apps/web"; printf '{"scripts":{"test:e2e":"playwright test"}}' > "$r/apps/web/package.json"
"$RUNNER_DETECT" --root "$r" >/dev/null 2>&1; assert_rc "$?" "0" "workspace package.json → present"

finish
