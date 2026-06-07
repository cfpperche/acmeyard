#!/usr/bin/env bash
# LIVE (spec 152.1): multi-page `audit` sweep — clean page passes, bad page flags.
source "$(dirname "$0")/_lib.sh"
echo "12-dogfood-audit (live)"
need_live || { finish; exit 0; }

bash "$TOOL" reset >/dev/null 2>&1
OUT="$WORK/audit"
# screen.html is clean (1 h1, main, nav); bad-page.html has 2 h1 + no <main> + list trap
RES="$(bash "$TOOL" audit "file://$FIXTURES" --paths "screen.html,bad-page.html" --out "$OUT" --max-console 0 2>&1)"; RC=$?
echo "$RES" | sed 's/^/    /'

assert_rc "$RC" 1 "sweep exits non-zero because one page is flagged"
assert_eq "$(jq -r '.total' "$OUT/report.json")" "2" "two pages audited"
assert_eq "$(jq -r '.flagged' "$OUT/report.json")" "1" "exactly one page flagged"
# clean page: 1 h1, main present, ok
assert_eq "$(jq -r '.pages[] | select(.label=="screen.html") | "\(.h1)/\(.main)/\(.ok)"' "$OUT/report.json")" "1/1/true" "clean page: h1=1, main, ok"
# bad page: h1 read as exactly 2 (NOT 2+listitems — the dogfood bug), no main, flagged
assert_eq "$(jq -r '.pages[] | select(.label=="bad-page.html") | "\(.h1)/\(.main)/\(.ok)"' "$OUT/report.json")" "2/0/false" "bad page: h1=2 (listitems not overcounted), no main, flagged"
[ -s "$OUT/shots/screen.html.png" ] && { PASS=$((PASS+1)); echo "  ✓ per-page screenshot captured"; } || { FAIL=$((FAIL+1)); echo "  ✗ screenshot missing"; }

# optional structure mode: fragment-like pages are allowed, overflow is recorded
bash "$TOOL" reset >/dev/null 2>&1
FRAG_OUT="$WORK/audit-fragments"
RES="$(bash "$TOOL" audit "file://$FIXTURES" --paths "frag-clean.html,frag-overflow.html" --out "$FRAG_OUT" --max-console 0 --structure optional 2>&1)"; RC=$?
echo "$RES" | sed 's/^/    /'

assert_rc "$RC" 0 "optional fragments audit rc 0"
assert_eq "$(jq -r '[.pages[].ok] | all' "$FRAG_OUT/report.json")" "true" "optional mode lets both fragments pass"
assert_eq "$(jq -r '.pages[] | select(.label=="frag-overflow.html") | .overflow_375' "$FRAG_OUT/report.json")" "true" "wide fragment records overflow_375"
assert_eq "$(jq -r '[.pages[].structure_mode] | unique | join(",")' "$FRAG_OUT/report.json")" "optional" "report records optional structure mode"
[ -s "$FRAG_OUT/shots/frag-clean.html-375.png" ] && [ -s "$FRAG_OUT/shots/frag-overflow.html-1280.png" ] \
  && { PASS=$((PASS+1)); echo "  ✓ responsive screenshots captured"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ responsive screenshots missing"; }

finish
