#!/usr/bin/env bash
# .agent0/tools/ui-impact-detect.sh — spec 206, retire-visual-contract-gate
# (originally spec 155; the visual-contract acceptance gate it fed was retired).
#
# Deterministic, content-free heuristic: given a set of changed paths, decide
# whether any of them is a RENDERED BROWSER SURFACE. It answers "did UI change?"
# so the validator can pair it with `ui-runner-detect.sh` and emit a non-blocking
# `ui-runner-advisory:` when UI surfaces changed but the project declares no UI
# test runner. It only DETECTS surfaces; the author's `UI impact: none|ui`
# declaration is the source of truth for whether proof is owed. The detector
# never sets a gate (matching tdd/lint/typecheck advisories).
#
# Note: the legacy `--declared` tier vocabulary (render|interaction|flow) is
# accepted but collapsed — any non-`none` declared value is treated as `ui`.
#
# Input (one of):
#   --range <git-range>   classify `git diff --name-only <range>`
#   (stdin)               newline-separated path list (default when no --range)
# Options:
#   --declared <level>    the author's declared level (none|ui; legacy
#                         render|interaction|flow accepted as `ui`);
#                         absent/empty is treated as `none`
#   --json                emit a JSON object instead of text
#
# Output (text):  two lines — `suggested: <level>` and `mismatch: <true|false>`,
#                 plus a `surfaces:` line listing matched paths (may be empty).
# Output (json):  { "suggested", "declared", "mismatch", "surfaces": [...] }
# Exit: always 0 (a detector reports; it does not gate). Usage error → 2.
set -uo pipefail

range=""; declared="none"; json=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --range) range="${2:-}"; shift 2 || { echo "ui-impact-detect: --range needs a value" >&2; exit 2; } ;;
    --declared) declared="${2:-none}"; shift 2 || { echo "ui-impact-detect: --declared needs a value" >&2; exit 2; } ;;
    --json) json=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "ui-impact-detect: unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$declared" ] || declared="none"

# Gather changed paths.
paths=""
if [ -n "$range" ]; then
  paths="$(git diff --name-only "$range" 2>/dev/null || true)"
else
  # stdin (non-tty); empty is allowed (→ no surfaces).
  if [ ! -t 0 ]; then paths="$(cat)"; fi
fi

# A path is EXCLUDED (never a UI surface) when it is docs/markdown, harness
# internals, tests, migrations, deps/build output, or a server-language source.
# Templates (.blade.php etc.) are matched as surfaces BEFORE the server-lang
# exclusion, so a Blade view is not lost to the `.php` rule.
is_excluded() {
  case "$1" in
    *.blade.php) return 1 ;;                                   # template — not excluded
  esac
  printf '%s\n' "$1" | grep -qiE \
    '(^|/)(docs|node_modules|\.git|\.agent0|vendor|dist|build|migrations|__tests__|test|tests|spec|specs|coverage)/|\.md$|\.(sql|go|rs|py|rb|java|kt|cs|sh|lock|toml|php)$|(^|/)(package(-lock)?|composer|bun|pnpm-lock|yarn)\.[a-z]+$'
}

# A path is a RENDERED SURFACE when (and only when) it is NOT excluded and it is
# a web component/style/template by extension, or sits in a UI directory.
is_surface() {
  is_excluded "$1" && return 1
  printf '%s\n' "$1" | grep -qiE \
    '\.(tsx|jsx|vue|svelte|astro|mdx)$|\.(css|scss|sass|less|styl)$|\.(html|hbs|ejs|pug|erb|twig)$|\.blade\.php$|(^|/)(components?|pages?|app|views?|layouts?|routes?|screens?|ui|styles?|theme|design-system)/'
}

surfaces=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if is_surface "$p"; then surfaces="${surfaces}${p}"$'\n'; fi
done <<< "$paths"
surfaces="$(printf '%s' "$surfaces" | sed '/^$/d')"

# Suggested floor: any surface ⇒ at least `render` (the detector cannot infer
# interaction/flow depth from paths — that is the author's call). Else `none`.
if [ -n "$surfaces" ]; then suggested="render"; else suggested="none"; fi

# Mismatch: surfaces changed but the author declared no contract is owed.
mismatch=false
case "$declared" in
  render|interaction|flow) : ;;                                # author declared depth — no mismatch
  *) [ -n "$surfaces" ] && mismatch=true ;;
esac

if [ "$json" -eq 1 ]; then
  # Build a JSON array of surfaces without assuming jq is present.
  arr="[]"
  if [ -n "$surfaces" ] && command -v jq >/dev/null 2>&1; then
    arr="$(printf '%s\n' "$surfaces" | jq -R . | jq -s -c .)"
  elif [ -n "$surfaces" ]; then
    arr="[$(printf '%s' "$surfaces" | sed 's/.*/"&"/' | paste -sd, -)]"
  fi
  printf '{"suggested":"%s","declared":"%s","mismatch":%s,"surfaces":%s}\n' \
    "$suggested" "$declared" "$mismatch" "$arr"
else
  printf 'suggested: %s\n' "$suggested"
  printf 'declared: %s\n' "$declared"
  printf 'mismatch: %s\n' "$mismatch"
  printf 'surfaces:%s\n' "$([ -n "$surfaces" ] && printf ' %s' $surfaces || printf ' (none)')"
fi
exit 0
