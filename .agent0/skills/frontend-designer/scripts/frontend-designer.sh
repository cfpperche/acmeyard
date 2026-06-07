#!/usr/bin/env bash
# frontend-designer.sh — deterministic mechanics for the /frontend-designer skill.
#
# The CRAFT (taste, design judgment, code) is prompt-driven by the agent reading
# SKILL.md. This script only does the boring/repeatable, testable parts so they
# stay mechanical and drift-free:
#   caps          report hard-dependency availability (tri-state)
#   detect        inspect a target project: framework / design-system / /product
#                 artifacts / browser-renderable harness / package manager
#   artifacts-dir resolve the git-tracked location for the design-doc pair
#   scaffold-docs write the reference-research.md + design-direction.md pair
#   verify        thin, FAIL-CLOSED wrapper over agent-browser.sh verify-contract
#
# No frozen stack opinions: detection only REPORTS what a project already is; the
# agent uses the stack ladder (references/stack-ladder.md) to decide, never this
# script. Done-proof reuses spec 155 (agent-browser verify-contract) — this adds
# no acceptance machinery; agent-browser unavailable is a BLOCKER, never a pass.
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SELF_DIR/.." && pwd)"
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"
AGENT_BROWSER="${FD_AGENT_BROWSER:-$REPO_ROOT/.agent0/tools/agent-browser.sh}"
TEMPLATES="$SKILL_DIR/templates"

die() { printf 'frontend-designer: %s\n' "$*" >&2; exit "${2:-1}"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------------------------- caps
cmd_caps() {
  local json=false; [ "${1:-}" = "--json" ] && json=true
  local rg jqs ab pm
  rg=$(have rg && echo present || echo absent)
  jqs=$(have jq && echo present || echo absent)
  if [ -x "$AGENT_BROWSER" ]; then
    local r; r="$(bash "$AGENT_BROWSER" route 2>/dev/null || echo unavailable:error)"
    case "$r" in primary*) ab=present;; *) ab="absent ($r)";; esac
  else ab="absent (no-wrapper)"; fi
  if $json; then
    jq -n --arg rg "$rg" --arg jq "$jqs" --arg ab "$ab" \
      '{shell:"present",rg:$rg,jq:$jq,"agent-browser":$ab}'
  else
    printf 'shell: present\nrg: %s\njq: %s\nagent-browser: %s\n' "$rg" "$jqs" "$ab"
  fi
}

# ----------------------------------------------------------------------------- detect
_pkg_has() { # <path> <dep-name> ; true if dep present in package.json
  local pj="$1/package.json" dep="$2"
  [ -f "$pj" ] || return 1
  jq -e --arg d "$dep" '((.dependencies//{})+(.devDependencies//{})) | has($d)' "$pj" >/dev/null 2>&1
}

_detect_framework() {
  local p="$1"
  if _pkg_has "$p" next; then echo next; return; fi
  if _pkg_has "$p" expo; then echo expo; return; fi
  if _pkg_has "$p" react-native; then echo react-native; return; fi
  if _pkg_has "$p" "@tauri-apps/api" || _pkg_has "$p" "@tauri-apps/cli"; then echo tauri; return; fi
  if _pkg_has "$p" electron; then echo electron; return; fi
  if _pkg_has "$p" nuxt; then echo nuxt; return; fi
  if _pkg_has "$p" "@sveltejs/kit"; then echo sveltekit; return; fi
  if _pkg_has "$p" svelte; then echo svelte; return; fi
  if _pkg_has "$p" vue; then echo vue; return; fi
  if _pkg_has "$p" "@angular/core"; then echo angular; return; fi
  if _pkg_has "$p" astro; then echo astro; return; fi
  if _pkg_has "$p" react; then echo react; return; fi
  if ls "$p"/*.html >/dev/null 2>&1 || [ -f "$p/index.html" ]; then echo html; return; fi
  echo unknown
}

_detect_design_system() {
  local p="$1" ds=()
  { [ -f "$p/tailwind.config.js" ] || [ -f "$p/tailwind.config.ts" ] || \
    [ -f "$p/tailwind.config.cjs" ] || [ -f "$p/tailwind.config.mjs" ] || \
    _pkg_has "$p" tailwindcss; } && ds+=("tailwind")
  [ -f "$p/components.json" ] && ds+=("shadcn")
  _pkg_has "$p" "@radix-ui/react-dialog" && ds+=("radix")
  _pkg_has "$p" "@mui/material" && ds+=("mui")
  _pkg_has "$p" "@chakra-ui/react" && ds+=("chakra")
  # token files
  { [ -f "$p/tokens.json" ] || [ -f "$p/design-tokens.json" ] || \
    ls "$p"/**/tokens.json >/dev/null 2>&1; } && ds+=("tokens")
  # /product-generated or hand-written design-system doc
  if ls "$p"/docs/**/design-system*.md >/dev/null 2>&1 || \
     ls "$p"/docs/design-system*.md >/dev/null 2>&1 || \
     [ -d "$p/vendor/open-design" ]; then ds+=("product-ds"); fi
  if [ "${#ds[@]}" -eq 0 ]; then echo "none"; else (IFS=,; echo "${ds[*]}"); fi
}

_detect_product_artifacts() {
  local p="$1"
  if ls "$p"/docs/**/concept-brief*.md >/dev/null 2>&1 || \
     ls "$p"/docs/**/design-system*.md >/dev/null 2>&1 || \
     ls "$p"/docs/**/fixture-spec*.json >/dev/null 2>&1 || \
     [ -d "$p/vendor/open-design" ]; then echo present; else echo absent; fi
}

_detect_browser_renderable() {
  local p="$1" fw; fw="$(_detect_framework "$p")"
  case "$fw" in
    next|nuxt|sveltekit|svelte|vue|angular|astro|react|html) echo yes; return;;
  esac
  # native frameworks: renderable only via a project-provided web harness
  [ -d "$p/.storybook" ] && { echo "yes (storybook)"; return; }
  _pkg_has "$p" "react-native-web" && { echo "yes (expo-web)"; return; }
  { [ -f "$p/index.html" ] || ls "$p"/*.html >/dev/null 2>&1; } && { echo yes; return; }
  echo no
}

_detect_pm() {
  local p="$1"
  [ -f "$p/bun.lockb" ] && { echo bun; return; }
  [ -f "$p/pnpm-lock.yaml" ] && { echo pnpm; return; }
  [ -f "$p/yarn.lock" ] && { echo yarn; return; }
  [ -f "$p/package-lock.json" ] && { echo npm; return; }
  [ -f "$p/package.json" ] && { echo "npm (no lockfile)"; return; }
  echo none
}

cmd_detect() {
  local p="" json=false
  while [ $# -gt 0 ]; do case "$1" in
    --json) json=true; shift;;
    *) p="$1"; shift;; esac; done
  [ -n "$p" ] || die "detect: usage: detect <path> [--json]" 3
  [ -d "$p" ] || die "detect: not a directory: $p" 3
  local fw ds pa br pm
  fw="$(_detect_framework "$p")"
  ds="$(_detect_design_system "$p")"
  pa="$(_detect_product_artifacts "$p")"
  br="$(_detect_browser_renderable "$p")"
  pm="$(_detect_pm "$p")"
  if $json; then
    jq -n --arg fw "$fw" --arg ds "$ds" --arg pa "$pa" --arg br "$br" --arg pm "$pm" \
      '{framework:$fw,design_system:$ds,product_artifacts:$pa,browser_renderable:$br,package_manager:$pm}'
  else
    printf 'framework: %s\ndesign_system: %s\nproduct_artifacts: %s\nbrowser_renderable: %s\npackage_manager: %s\n' \
      "$fw" "$ds" "$pa" "$br" "$pm"
  fi
}

# ----------------------------------------------------------------------------- artifacts-dir
cmd_artifacts_dir() {
  local p="" spec="" surface=""
  while [ $# -gt 0 ]; do case "$1" in
    --spec) spec="$2"; shift 2;;
    --surface) surface="$2"; shift 2;;
    *) p="$1"; shift;; esac; done
  [ -n "$p" ] || die "artifacts-dir: usage: artifacts-dir <path> [--spec NNN] --surface <s>" 3
  [ -n "$surface" ] || die "artifacts-dir: --surface required" 3
  if [ -n "$spec" ]; then
    local d; d="$(ls -d "$p"/docs/specs/"$spec"-* 2>/dev/null | head -1)"
    [ -n "$d" ] && { echo "$d"; return; }
  fi
  echo "$p/docs/design/$surface"
}

# ----------------------------------------------------------------------------- scaffold-docs
cmd_scaffold_docs() {
  local p="" spec="" surface=""
  while [ $# -gt 0 ]; do case "$1" in
    --spec) spec="$2"; shift 2;;
    --surface) surface="$2"; shift 2;;
    *) p="$1"; shift;; esac; done
  [ -n "$p" ] || die "scaffold-docs: usage: scaffold-docs <path> --surface <s> [--spec NNN]" 3
  [ -n "$surface" ] || die "scaffold-docs: --surface required" 3
  local dir; dir="$(cmd_artifacts_dir "$p" ${spec:+--spec "$spec"} --surface "$surface")"
  mkdir -p "$dir"
  local date; date="$(date -u +%Y-%m-%d)"
  for base in reference-research design-direction; do
    local dest="$dir/$base.md"
    if [ -f "$dest" ]; then
      printf 'frontend-designer: exists, not overwriting: %s\n' "$dest" >&2
      continue
    fi
    sed -e "s/{{SURFACE}}/$surface/g" -e "s/{{DATE}}/$date/g" \
      "$TEMPLATES/$base.md.tmpl" > "$dest"
    printf 'wrote %s\n' "$dest"
  done
}

# ----------------------------------------------------------------------------- verify (fail-closed wrapper)
cmd_verify() {
  local url="${1:-}" fixture="${2:-}" outdir="${3:-}"
  [ -n "$url" ] && [ -n "$fixture" ] && [ -n "$outdir" ] || \
    die "verify: usage: verify <url> <fixture.json> <outdir>" 3
  [ -f "$fixture" ] || die "verify: fixture not found: $fixture" 3
  # FAIL CLOSED: browser visual proof requires agent-browser. Unavailable is a
  # BLOCKER, never a pass (spec 155 / meeting D6).
  local route; route="$(bash "$AGENT_BROWSER" route 2>/dev/null || echo unavailable:error)"
  case "$route" in
    primary*) ;;
    *) die "BLOCKER: agent-browser is $route — browser visual proof CANNOT be produced. This is NOT a pass. Install agent-browser + Chrome, or prove a native-only surface via the honest-evidence path (references/done-proof.md)." 4;;
  esac
  bash "$AGENT_BROWSER" verify-contract "$url" "$fixture" "$outdir"
}

# ----------------------------------------------------------------------------- dispatch
sub="${1:-}"; shift || true
case "$sub" in
  caps)          cmd_caps "$@" ;;
  detect)        cmd_detect "$@" ;;
  artifacts-dir) cmd_artifacts_dir "$@" ;;
  scaffold-docs) cmd_scaffold_docs "$@" ;;
  verify)        cmd_verify "$@" ;;
  ""|help|-h|--help)
    cat <<EOF
frontend-designer.sh — deterministic mechanics for /frontend-designer
  caps [--json]                              hard-dep availability
  detect <path> [--json]                     framework/design-system/product/harness/pm
  artifacts-dir <path> [--spec NNN] --surface <s>   resolve design-doc location
  scaffold-docs <path> --surface <s> [--spec NNN]   write the design-doc pair
  verify <url> <fixture.json> <outdir>       fail-closed verify-contract wrapper
EOF
    ;;
  *) die "unknown subcommand: $sub (try: help)" 3 ;;
esac
