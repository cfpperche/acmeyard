#!/usr/bin/env bash
# garbage source -> structural error (Chrome-less), no broken output.
source "$(dirname "$0")/_lib.sh"; echo "03-invalid-source"
OUT="$(bash "$TOOL" "this is definitely not a diagram" --kind flowchart)"; RC=$?
assert_eq "$RC" "0" "default exit 0"
assert_contains "$OUT" "status=error" "garbage -> error"
assert_contains "$OUT" "does not look like a Mermaid diagram" "names the structural failure"
assert_eq "$(ls "$WORK/out" | grep -c '\.svg$')" "0" "no corrupt svg written"
# comment-only-then-keyword still validates (real mermaid allows %% comments)
OK="$(bash "$TOOL" "%% a comment
flowchart LR
 X-->Y")"
assert_contains "$OK" "status=ok" "leading %% comment tolerated, then valid keyword"
# --exit-code maps error=3
bash "$TOOL" "garbage" --exit-code >/dev/null 2>&1; assert_eq "$?" "3" "--exit-code maps error=3"
finish
