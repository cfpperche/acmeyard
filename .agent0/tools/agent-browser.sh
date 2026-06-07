#!/usr/bin/env bash
# Agent0 `agent-browser` — harness wrapper / operational envelope around the
# vercel-labs `agent-browser` CLI (spec 152, browser-primitive-consolidation).
#
# Turns the raw CLI into Agent0's SOLE, runtime-neutral agent browser
# primitive (eyes + hands + observe) with: binary/Chrome detection, fail-closed
# routing, a policy-as-file guard, per-command audit logging, and a fail-readable
# JSON contract. There is NO MCP fallback — when agent-browser is unavailable the
# wrapper FAILS CLOSED (rc 4) rather than degrading to Playwright / Chrome DevTools
# MCP (spec 153). Those MCPs survive ONLY as opt-in .mcp.json.example /
# .codex/config.toml.example templates a consumer may wire up by hand. See
# .agent0/context/rules/browser-primitive.md.
#
# Runtime-neutral: Claude Code and Codex CLI both invoke it through plain shell,
# NO per-runtime MCP wiring, NO session restart. Reports + gates; the heavy
# lifting is delegated to `agent-browser` itself.
#
# Subcommands:
#   caps [--json]                       detect binary+chrome+version (tri-state)
#   route [task]                        print: primary | unavailable:<reason>
#   policy-eval <action> <target> [--confirm]   decision: allow|deny|confirm ; reason
#   run [--confirm] -- <agent-browser args...>   policy-gated, audited passthrough
#   verify-contract <url> <fixture.json> <outdir>   bounded visual-contract verify
#   audit <base-url> (--paths a,b,c|--paths-file f) [--out d] [--max-console N] [--structure strict|optional]   multi-page structural+console+vitals+overflow sweep
#   adopt <host> [--port 9222] [--domain d] [--timeout S] [--state f] [--detect-only]   attach to a human-logged-in CDP Chrome, save state (152.2)
#   audit-tail [N]                      show recent audit lines
#   help
#
# Exit: 0 ok; 2 policy-denied; 3 usage / unsupported override; 4 agent-browser unavailable (fail-closed).

set -uo pipefail

# --- pinned version (advisory drift, never blocks) --------------------------
PINNED_VERSION="0.27.1"

# --- roots ------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "${AGENT0_PROJECT_DIR:-}" ]; then
  PROJECT_DIR="$AGENT0_PROJECT_DIR"
else
  PROJECT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$PROJECT_DIR" ] || PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
fi

POLICY_FILE="${AGENT0_BROWSER_POLICY:-$PROJECT_DIR/.agent0/browser-policy.json}"
AUDIT_DIR="$PROJECT_DIR/.agent0/.runtime-state/agent-browser"

# --- binary + chrome detection (overridable for tests) ----------------------
# AGENT0_BROWSER_BIN lets tests mask/redirect the binary; default resolves PATH.
ab_bin() { echo "${AGENT0_BROWSER_BIN:-agent-browser}"; }
have_binary() { command -v "$(ab_bin)" >/dev/null 2>&1; }

# Resolve a usable Chrome executable: explicit env wins, else common system paths.
resolve_chrome() {
  if [ -n "${AGENT_BROWSER_EXECUTABLE_PATH:-}" ] && [ -x "${AGENT_BROWSER_EXECUTABLE_PATH}" ]; then
    echo "${AGENT_BROWSER_EXECUTABLE_PATH}"; return 0
  fi
  local c
  for c in google-chrome google-chrome-stable chromium chromium-browser; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  # agent-browser may ship/download its own Chrome-for-Testing; treat as present.
  return 1
}

detected_version() {
  have_binary || return 1
  "$(ab_bin)" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# --- policy (jq-parsed JSON; safe built-in defaults when no file) -----------
# Defaults: mode=audit; localhost/127.0.0.1 allowlisted; file:// always local.
DEFAULT_ALLOWLIST='["localhost","127.0.0.1"]'
DEFAULT_SENSITIVE='["upload","download","eval","cookies","storage","network","pdf"]'

policy_get() { # policy_get <jq-filter> <fallback-json>
  local filter="$1" fallback="$2"
  if [ -f "$POLICY_FILE" ]; then
    jq -c "$filter // ($fallback)" "$POLICY_FILE" 2>/dev/null || printf '%s' "$fallback"
  else
    printf '%s' "$fallback"
  fi
}
policy_mode()      { policy_get '.mode' '"audit"' | tr -d '"'; }
policy_allowlist() { policy_get '.allowlist' "$DEFAULT_ALLOWLIST"; }
policy_sensitive() { policy_get '.sensitive_actions' "$DEFAULT_SENSITIVE"; }

# Classify an agent-browser subcommand token into read-only|interactive|sensitive.
READONLY_ACTIONS=" open snapshot screenshot console errors vitals get is find title url count box styles diff wait scrollintoview highlight react "
INTERACTIVE_ACTIONS=" click dblclick type fill press keyboard hover focus check uncheck select drag scroll mouse set tab pushstate "
classify_action() { # classify_action <action>
  local a="$1"
  if printf '%s' "$(policy_sensitive)" | jq -e --arg a "$a" 'index($a) != null' >/dev/null 2>&1; then
    echo "sensitive"; return
  fi
  case "$READONLY_ACTIONS" in *" $a "*) echo "read-only"; return;; esac
  case "$INTERACTIVE_ACTIONS" in *" $a "*) echo "interactive"; return;; esac
  echo "sensitive"  # unknown ⇒ treat as sensitive (fail-safe)
}

# Is a target host allowlisted? file:// and allowlisted hosts ⇒ yes.
host_allowlisted() { # host_allowlisted <target>
  local t="$1" host
  case "$t" in
    file://*|/*|./*|"") return 0 ;;  # local file paths / refs / empty ⇒ local
  esac
  host="$(printf '%s' "$t" | sed -E 's#^[a-zA-Z]+://##; s#[/?#].*$##; s#:[0-9]+$##')"
  [ -n "$host" ] || return 0
  printf '%s' "$(policy_allowlist)" | jq -e --arg h "$host" 'index($h) != null' >/dev/null 2>&1
}

# policy_eval <action> <target> [--confirm] → prints "decision\treason"; exit 0 allow,2 deny.
policy_eval() {
  local action="$1" target="${2:-}" confirm="no"
  [ "${3:-}" = "--confirm" ] && confirm="yes"
  local class; class="$(classify_action "$action")"
  case "$class" in
    read-only)
      # cross-origin navigation to a non-allowlisted host is still externally sensitive
      if [ "$action" = "open" ] && ! host_allowlisted "$target"; then
        if [ "$confirm" = "yes" ]; then echo -e "allow\texternal-nav-confirmed"; return 0
        else echo -e "confirm\texternal-nav-needs-confirm"; return 2; fi
      fi
      echo -e "allow\tread-only"; return 0 ;;
    interactive)
      if host_allowlisted "$target"; then echo -e "allow\tsame-origin-interactive"; return 0
      elif [ "$confirm" = "yes" ]; then echo -e "allow\texternal-interactive-confirmed"; return 0
      else echo -e "confirm\texternal-interactive-needs-confirm"; return 2; fi ;;
    sensitive)
      if [ "$confirm" = "yes" ]; then echo -e "allow\tsensitive-confirmed"; return 0
      elif host_allowlisted "$target" && [ "$action" != "eval" ]; then echo -e "allow\tsensitive-allowlisted"; return 0
      else echo -e "deny\tsensitive-needs-confirm"; return 2; fi ;;
  esac
}

# --- audit ------------------------------------------------------------------
audit_line() { # audit_line <cmd> <action> <target> <class> <decision> <guard>
  mkdir -p "$AUDIT_DIR" 2>/dev/null || return 0
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local f="$AUDIT_DIR/audit-$(date -u +%Y-%m-%d).jsonl"
  jq -cn --arg ts "$ts" --arg cmd "$1" --arg action "$2" --arg target "$3" \
        --arg class "$4" --arg decision "$5" --arg guard "$6" \
        '{ts:$ts,cmd:$cmd,action:$action,target:$target,class:$class,decision:$decision,guard:$guard}' \
        >> "$f" 2>/dev/null || true
}

# --- routing (fail-closed; NO MCP fallback — spec 153) ----------------------
# agent-browser is the SOLE primitive. `route` prints `primary` when usable, else
# `unavailable:<reason>`. There is no MCP lane: when unavailable the command layer
# fails closed (rc 4) instead of degrading to Playwright/Chrome DevTools MCP. The
# legacy `AGENT0_BROWSER=mcp` override is now an explicit unsupported error
# (`unavailable:mcp-removed`) — those MCPs live only as opt-in .example templates.
CAPABILITY_GAPS=" "   # v1: none — agent-browser is a superset. Reserved slot.
route() {
  local task="${1:-}"
  if [ "${AGENT0_BROWSER:-}" = "mcp" ]; then echo "unavailable:mcp-removed"; return 0; fi
  if ! have_binary; then echo "unavailable:no-binary"; return 0; fi
  # agent-browser self-provides Chrome-for-Testing, so a missing SYSTEM Chrome is
  # NOT itself an unavailability reason — only an explicit "no usable browser"
  # signal is (AGENT0_BROWSER_NO_CHROME=1), surfaced by doctor when even the
  # bundled browser is unavailable.
  if [ "${AGENT0_BROWSER_NO_CHROME:-}" = "1" ]; then echo "unavailable:no-chrome"; return 0; fi
  if [ -n "$task" ]; then
    case "$CAPABILITY_GAPS" in *" $task "*) echo "unavailable:capability-gap:$task"; return 0;; esac
  fi
  echo "primary"
}

# Resolve the route for an explicit browser command; on non-primary, print the
# fail-closed message and return the right rc (3 for the removed-mcp override,
# 4 for genuine unavailability). Callers: `require_primary <label> || return $?`.
require_primary() {
  local label="${1:-command}" r; r="$(route)"
  [ "$r" = "primary" ] && return 0
  if [ "$r" = "unavailable:mcp-removed" ]; then
    echo "unsupported: AGENT0_BROWSER=mcp — MCP routing removed in spec 153; Playwright/Chrome DevTools MCP survive only as an opt-in .mcp.json.example template, not a harness fallback." >&2
    return 3
  fi
  echo "agent-browser unavailable ($r) for $label — fail-closed (NO MCP fallback, spec 153). Install agent-browser + a Chrome, then verify: bash .agent0/tools/agent-browser.sh caps · bash .agent0/tools/doctor.sh" >&2
  return 4
}

# --- daemon lifecycle -------------------------------------------------------
# agent-browser runs a single persistent daemon that IGNORES launch options
# (--profile/--state/--session-name) if already up. `reset` tears it down so the
# next call binds fresh. Surgical: matches ONLY processes whose argv[0] ends in
# the daemon binary — never this shell (whose cmdline contains the pattern).
daemon_pids() {
  pgrep -af agent-browser-linux 2>/dev/null | awk '$2 ~ /agent-browser-linux[^ ]*$/{print $1}'
}
reset_daemon() {
  # `close --all` HANGS if no daemon is running — only call it when one exists,
  # and cap it with a timeout as belt-and-suspenders.
  if [ -n "$(daemon_pids)" ]; then
    timeout 8 "$(ab_bin)" close --all >/dev/null 2>&1 || true
  fi
  daemon_pids | xargs -r kill 2>/dev/null || true
  sleep 1
}

# --- caps -------------------------------------------------------------------
caps() {
  local json="no"; [ "${1:-}" = "--json" ] && json="yes"
  local bin_present="no" chrome_path="" ver="" ver_state="unknown"
  have_binary && bin_present="yes"
  chrome_path="$(resolve_chrome 2>/dev/null || true)"
  if [ "$bin_present" = "yes" ]; then
    ver="$(detected_version || true)"
    if [ -z "$ver" ]; then ver_state="unknown"
    elif [ "$ver" = "$PINNED_VERSION" ]; then ver_state="pinned"
    else ver_state="drift"; fi
  fi
  if [ "$json" = "yes" ]; then
    jq -cn --arg bin "$bin_present" --arg chrome "${chrome_path:-}" --arg ver "${ver:-}" \
          --arg pinned "$PINNED_VERSION" --arg vstate "$ver_state" \
          '{binary:$bin,chrome:$chrome,version:$ver,pinned:$pinned,version_state:$vstate}'
  else
    echo "binary:        $bin_present"
    echo "chrome:        ${chrome_path:-<none on PATH; agent-browser may self-provide>}"
    echo "version:       ${ver:-<unknown>} (pinned $PINNED_VERSION; $ver_state)"
  fi
}

# --- run (policy-gated, audited passthrough) --------------------------------
run() {
  local confirm_flag=""
  if [ "${1:-}" = "--confirm" ]; then confirm_flag="--confirm"; shift; fi
  if [ "${1:-}" = "--" ]; then shift; fi
  [ "$#" -ge 1 ] || { echo "usage: agent-browser.sh run [--confirm] -- <agent-browser args...>" >&2; return 3; }

  require_primary run || return $?

  # Find the real action + target by scanning past leading global flags
  # (--profile <v>, --session-name <v>, --engine <v>, etc. precede the subcommand).
  local action="" target="" seen_action="no" prev=""
  for tok in "$@"; do
    if [ "$seen_action" = "no" ]; then
      case " $READONLY_ACTIONS $INTERACTIVE_ACTIONS " in
        *" $tok "*) action="$tok"; seen_action="yes"; continue ;;
      esac
      # also catch sensitive-classified actions (from the policy list)
      if printf '%s' "$(policy_sensitive)" | jq -e --arg a "$tok" 'index($a) != null' >/dev/null 2>&1; then
        action="$tok"; seen_action="yes"; continue
      fi
    elif [ -z "$target" ]; then
      case "$tok" in -*) : ;; *) target="$tok" ;; esac
    fi
  done
  [ -n "$action" ] || action="$1"   # fallback: first token
  local dec reason
  IFS=$'\t' read -r dec reason < <(policy_eval "$action" "$target" ${confirm_flag:+--confirm})
  audit_line "run" "$action" "$target" "$(classify_action "$action")" "$dec" "$reason"
  if [ "$dec" = "deny" ] || [ "$dec" = "confirm" ]; then
    echo "POLICY=$dec ($reason) for '$action ${target}'. Pass --confirm or allowlist the host (see .agent0/browser-policy.json.example)." >&2
    return 2
  fi

  # Default the browser executable to the system Chrome if not already set.
  local chrome; chrome="$(resolve_chrome 2>/dev/null || true)"
  [ -n "$chrome" ] && [ -z "${AGENT_BROWSER_EXECUTABLE_PATH:-}" ] && export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  "$(ab_bin)" "$@"
}

# --- verify-contract (the bounded visual-contract dogfood verifier) ---------
verify_contract() {
  local url="${1:-}" fixture="${2:-}" outdir="${3:-}"
  [ -n "$url" ] && [ -f "$fixture" ] && [ -n "$outdir" ] || {
    echo "usage: agent-browser.sh verify-contract <url> <fixture.json> <outdir>" >&2; return 3; }
  jq -e . "$fixture" >/dev/null 2>&1 || {
    echo "verify-contract: malformed fixture JSON: $fixture" >&2; return 3; }
  mkdir -p "$outdir"

  require_primary verify-contract || return $?

  local chrome; chrome="$(resolve_chrome 2>/dev/null || true)"
  [ -n "$chrome" ] && export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  local bin; bin="$(ab_bin)"

  audit_line "verify-contract" "open" "$url" "read-only" "allow" "contract-verify"
  "$bin" open "$url" >/dev/null 2>&1
  "$bin" snapshot --json > "$outdir/a11y.json" 2>/dev/null
  "$bin" screenshot "$outdir/screen.png" >/dev/null 2>&1
  "$bin" console --json > "$outdir/console.json" 2>/dev/null || echo '{"data":{"messages":[]}}' > "$outdir/console.json"
  "$bin" vitals --json > "$outdir/vitals.json" 2>/dev/null || echo '{}' > "$outdir/vitals.json"

  # --- assert against the fixture-spec ---
  local checks="[]" overall="pass"
  add_check() { # add_check <name> <ok-bool> <detail> [flaky-bool]
    # A failing step marked flaky is recorded as a non-fatal `warn` check: it
    # appears in the report but does NOT flip `overall` to fail (spec 155 D5 —
    # interactive/flow steps are flakier; flakiness must not break a build).
    local flaky="${4:-false}" warn=false
    if [ "$2" != "true" ] && [ "$flaky" = "true" ]; then warn=true; fi
    checks="$(jq -c --arg n "$1" --argjson ok "$2" --arg d "$3" --argjson warn "$warn" \
      '. + [{name:$n,ok:$ok,warn:$warn,detail:$d}]' <<<"$checks")"
    if [ "$2" != "true" ] && [ "$warn" != "true" ]; then overall="fail"; fi
  }
  # Resolve a {role,name} to a snapshot ref id (works whether `.data.refs` is an
  # object map keyed by ref id or an array). Empty when not found.
  _vc_ref() { jq -r --arg role "$2" --arg name "$3" \
      '((.data.refs // {}) | to_entries | map(select(.value.role==$role and .value.name==$name)) | (.[0].key // empty))' \
      "$1" 2>/dev/null; }
  _vc_present() { jq -r --arg role "$2" --arg name "$3" \
      '[((.data.refs // {}) | .[]) | select(.role==$role and .name==$name)] | length > 0' "$1" 2>/dev/null || echo false; }
  _vc_url() { jq -r '.data.url // empty' "$1" 2>/dev/null; }
  _vc_snap() { "$bin" snapshot --json > "$outdir/a11y.json" 2>/dev/null || true; }
  # Drive one act verb against the live binary via the resolved ref (best-effort
  # mapping onto the agent-browser CLI; the fake-bin stub records the call).
  _vc_act() { # <verb> <ref> [value]
    case "$1" in
      click)  "$bin" click "$2" >/dev/null 2>&1 ;;
      type)   "$bin" type "$2" "${3:-}" >/dev/null 2>&1 ;;
      select) "$bin" select "$2" "${3:-}" >/dev/null 2>&1 ;;
      press)  "$bin" press "${3:-$2}" >/dev/null 2>&1 ;;
      *) return 0 ;;
    esac
  }

  # required roles/names present in the a11y refs
  local nreq; nreq="$(jq '.required | length' "$fixture" 2>/dev/null || echo 0)"
  local i=0
  while [ "$i" -lt "${nreq:-0}" ]; do
    local role name found
    role="$(jq -r ".required[$i].role" "$fixture")"
    name="$(jq -r ".required[$i].name" "$fixture")"
    found="$(jq --arg role "$role" --arg name "$name" \
      '[.data.refs[] | select(.role==$role and .name==$name)] | length > 0' "$outdir/a11y.json" 2>/dev/null || echo false)"
    if [ "$found" = "true" ]; then add_check "required:$role:$name" true "present"
    else add_check "required:$role:$name" false "MISSING from a11y tree"; fi
    i=$((i+1))
  done

  # console errors within budget
  local maxerr nerr
  maxerr="$(jq '.max_console_errors // 0' "$fixture" 2>/dev/null || echo 0)"
  nerr="$(jq '[.data.messages[]? | select((.type//.level//"") == "error")] | length' "$outdir/console.json" 2>/dev/null || echo 0)"
  if [ "${nerr:-0}" -le "${maxerr:-0}" ]; then add_check "console-errors" true "$nerr ≤ $maxerr"
  else add_check "console-errors" false "$nerr > $maxerr"; fi

  # screenshot produced
  if [ -s "$outdir/screen.png" ]; then add_check "screenshot" true "captured"
  else add_check "screenshot" false "not produced"; fi

  # --- interaction tier (spec 155 D3): exercise named controls -------------
  # Each step: { action, target:{role,name}, value?, expect:{role,name}?, flaky? }.
  # Resolve the target ref from the current snapshot, drive the act verb, then
  # re-snapshot and assert the expected post-state role/name is present.
  local nint; nint="$(jq '(.interactions // []) | length' "$fixture" 2>/dev/null || echo 0)"
  local j=0
  while [ "$j" -lt "${nint:-0}" ]; do
    local act trole tname tval eflaky exp_role exp_name ref ok detail
    act="$(jq -r ".interactions[$j].action // \"click\"" "$fixture")"
    trole="$(jq -r ".interactions[$j].target.role // empty" "$fixture")"
    tname="$(jq -r ".interactions[$j].target.name // empty" "$fixture")"
    tval="$(jq -r ".interactions[$j].value // empty" "$fixture")"
    eflaky="$(jq -r ".interactions[$j].flaky // false" "$fixture")"
    exp_role="$(jq -r ".interactions[$j].expect.role // empty" "$fixture")"
    exp_name="$(jq -r ".interactions[$j].expect.name // empty" "$fixture")"
    ref="$(_vc_ref "$outdir/a11y.json" "$trole" "$tname")"
    if [ -z "$ref" ] && [ "$act" != "press" ]; then
      add_check "interaction:$act:$tname" false "target $trole/$tname not in a11y tree" "$eflaky"
      j=$((j+1)); continue
    fi
    _vc_act "$act" "$ref" "$tval"
    _vc_snap
    if [ -n "$exp_role" ]; then
      ok="$(_vc_present "$outdir/a11y.json" "$exp_role" "$exp_name")"
      [ "$ok" = "true" ] && detail="post-state $exp_role/$exp_name present" || detail="expected $exp_role/$exp_name MISSING after $act"
      add_check "interaction:$act:${tname:-$tval}" "$ok" "$detail" "$eflaky"
    else
      add_check "interaction:$act:${tname:-$tval}" true "executed (no post-assert)" "$eflaky"
    fi
    j=$((j+1))
  done

  # --- flow tier (spec 155 D3): ordered traversal from a start route -------
  # Each step: { goto?, action?, target?, value?, expect_url?(regex), expect?, flaky? }.
  local nflow; nflow="$(jq '(.flow // []) | length' "$fixture" 2>/dev/null || echo 0)"
  local k=0
  while [ "$k" -lt "${nflow:-0}" ]; do
    local goto act trole tname tval eurl exp_role exp_name eflaky ref ok detail
    goto="$(jq -r ".flow[$k].goto // empty" "$fixture")"
    act="$(jq -r ".flow[$k].action // empty" "$fixture")"
    trole="$(jq -r ".flow[$k].target.role // empty" "$fixture")"
    tname="$(jq -r ".flow[$k].target.name // empty" "$fixture")"
    tval="$(jq -r ".flow[$k].value // empty" "$fixture")"
    eurl="$(jq -r ".flow[$k].expect_url // empty" "$fixture")"
    exp_role="$(jq -r ".flow[$k].expect.role // empty" "$fixture")"
    exp_name="$(jq -r ".flow[$k].expect.name // empty" "$fixture")"
    eflaky="$(jq -r ".flow[$k].flaky // false" "$fixture")"
    ok=true; detail="step $((k+1))"
    if [ -n "$goto" ]; then
      audit_line "verify-contract" "open" "$goto" "read-only" "allow" "contract-flow"
      "$bin" open "$goto" >/dev/null 2>&1
      _vc_snap
    elif [ -z "$act" ]; then
      _vc_snap
    fi
    if [ -n "$act" ]; then
      ref="$(_vc_ref "$outdir/a11y.json" "$trole" "$tname")"
      if [ -z "$ref" ] && [ "$act" != "press" ]; then
        ok=false; detail="target $trole/$tname not in a11y tree"
      else
        _vc_act "$act" "$ref" "$tval"
        _vc_snap
      fi
    fi
    if [ -n "$eurl" ]; then
      local cur; cur="$(_vc_url "$outdir/a11y.json")"
      if printf '%s' "$cur" | grep -qE "$eurl"; then detail="url ~ $eurl"; else ok=false; detail="url '$cur' !~ $eurl"; fi
    fi
    if [ "$ok" = "true" ] && [ -n "$exp_role" ]; then
      ok="$(_vc_present "$outdir/a11y.json" "$exp_role" "$exp_name")"
      [ "$ok" = "true" ] && detail="$detail; $exp_role/$exp_name present" || detail="$detail; $exp_role/$exp_name MISSING"
    fi
    add_check "flow:$((k+1)):${tname:-${goto:-step}}" "$ok" "$detail" "$eflaky"
    k=$((k+1))
  done

  "$bin" close --all >/dev/null 2>&1 || true

  jq -cn --arg overall "$overall" --argjson checks "$checks" --arg url "$url" \
        '{url:$url,overall:$overall,checks:$checks}' > "$outdir/report.json"
  echo "VERIFY-CONTRACT: $(echo "$overall" | tr a-z A-Z)  ($url)"
  jq -r '.checks[] | "  " + (if .ok then "✓" else "✗" end) + " " + .name + " — " + .detail' "$outdir/report.json"
  [ "$overall" = "pass" ]
}

# --- adopt: attach to a human-logged-in Chrome over CDP, save state (152.2) --
# Pairs with browser-login.sh: the human launched a dedicated CDP Chrome and is
# logging in; `adopt` polls the CDP /json endpoint (HTTP, NON-disruptive — never
# navigates the human's tab) until a page on the host leaves the login flow,
# then saves the session state (credential-class). Never handles credentials.
adopt_session() {
  local host="${1:-}"; shift || true
  local port=9222 timeout=300 statefile="" domain="" expect="" detect_only="no"
  while [ "$#" -gt 0 ]; do case "$1" in
    --port)    port="$2"; shift 2 ;;
    --timeout) timeout="$2"; shift 2 ;;
    --state)   statefile="$2"; shift 2 ;;
    --domain)  domain="$2"; shift 2 ;;
    --expect)  expect="$2"; shift 2 ;;
    --detect-only) detect_only="yes"; shift ;;
    *) shift ;;
  esac; done
  [ -n "$host" ] || { echo "usage: agent-browser.sh adopt <host> [--port N] [--domain d] [--timeout S] [--state f] [--expect re]" >&2; return 3; }
  case "$host" in
    github)    domain="${domain:-github.com}" ;;
    x|twitter) domain="${domain:-x.com}" ;;
    linkedin)  domain="${domain:-linkedin.com}" ;;
    *)         domain="${domain:-$host}" ;;
  esac
  [ -n "$statefile" ] || statefile="$AUDIT_DIR/state/$host.json"

  require_primary adopt || return $?

  curl -s -m3 "http://localhost:$port/json/version" >/dev/null 2>&1 || {
    echo "adopt: no Chrome on CDP :$port — run  bash .agent0/tools/browser-login.sh $host  first." >&2; return 4; }

  local login_re='/(login|signin|sign_in|session|sessions|oauth|sso|challenge|checkpoint|authwall|i/flow|uas/login)'
  local deadline url=""; deadline=$(( $(date +%s) + timeout ))
  echo "adopt: watching CDP :$port for $host login (domain $domain, ≤${timeout}s; non-disruptive)…"
  while [ "$(date +%s)" -lt "$deadline" ]; do
    url="$(curl -s -m3 "http://localhost:$port/json" 2>/dev/null \
      | jq -r --arg d "$domain" '[.[] | select(.type=="page") | .url] | map(select(. != null and (test($d)))) | .[0] // ""' 2>/dev/null)"
    if [ -n "$url" ] && ! printf '%s' "$url" | grep -qiE "$login_re"; then
      if [ -z "$expect" ] || printf '%s' "$url" | grep -qE "$expect"; then break; fi
    fi
    url=""; sleep 3
  done
  [ -n "$url" ] || { echo "adopt: timed out — no authed $domain page seen on CDP :$port (still on the login flow?)." >&2; return 1; }

  if [ "$detect_only" = "yes" ]; then
    echo "DETECTED $host authed at $url"
    return 0
  fi

  mkdir -p "$(dirname "$statefile")"
  local chrome; chrome="$(resolve_chrome 2>/dev/null || true)"; [ -n "$chrome" ] && export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  "$(ab_bin)" --cdp "$port" state save "$statefile" >/dev/null 2>&1
  audit_line "adopt" "state-save" "$host" "sensitive" "allow" "cdp-adopt"
  local cookies; cookies="$(jq '.cookies | length' "$statefile" 2>/dev/null || echo 0)"
  echo "ADOPTED $host → $statefile (authed at $url; $cookies cookies). Reuse headless: agent-browser --state $statefile open https://$domain/"
  [ "${cookies:-0}" -ge 1 ]
}

# --- structural parsing of the a11y text tree (spec 152.1) ------------------
# CORRECT structural metrics from `.data.snapshot`. The naive trap (real, hit
# during the site-audit dogfood): `grep -c 'level=1'` ALSO matches
# `listitem [level=1]` (nesting depth), wildly overcounting h1s. Headings must
# be parsed on heading lines only, with the level token terminated by `,` or `]`.
# parse_structure <snapshot-text> → echoes "h1=<n> h2=<n> main=<0|1> nav=<0|1>"
parse_structure() {
  local tree="$1" h1 h2 main nav
  h1="$(printf '%s' "$tree" | grep -cE 'heading .*\[level=1[],]' || true)"
  h2="$(printf '%s' "$tree" | grep -cE 'heading .*\[level=2[],]' || true)"
  main="$(printf '%s' "$tree" | grep -cE '^[[:space:]]*- main([[:space:]"]|$)' || true)"; main=$([ "${main:-0}" -gt 0 ] && echo 1 || echo 0)
  nav="$(printf '%s' "$tree" | grep -cE '^[[:space:]]*- navigation([[:space:]"]|$)' || true)"; nav=$([ "${nav:-0}" -gt 0 ] && echo 1 || echo 0)
  echo "h1=${h1:-0} h2=${h2:-0} main=${main} nav=${nav}"
}

# --- audit: multi-page structural + console + vitals + overflow sweep --------
# audit <base-url> (--paths a,b,c | --paths-file f) [--out dir] [--max-console N] [--structure strict|optional]
# Owns the daemon lifecycle + report aggregation so callers don't hand-roll it
# (and don't re-make the grep bug above). Two structure modes (spec 153):
#   strict   (default) — gate = exactly one h1 + a main landmark + console ≤ max.
#                        Unchanged from 152.1; site-audit semantics.
#   optional           — h1/main are ADVISORY (recorded + flagged, never gating);
#                        gate = console ≤ max only. For landmark-less fragments
#                        like /product hi-fi mood screens that legitimately have
#                        no single h1 / main landmark.
# Responsive overflow (both modes, advisory): each page is screenshotted at 375px
# and 1280px and probed for horizontal overflow (scrollWidth > clientWidth) via a
# FIXED internal `eval` expression (no user input) — the documented OQ2 mechanism.
# nav/vitals stay advisory.
audit_pages() {
  local base="" paths="" out="$PROJECT_DIR/.agent0/.runtime-state/agent-browser/audit" maxc=0 structure="strict"
  base="${1:-}"; shift || true
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --paths) paths="$2"; shift 2 ;;
      --paths-file) paths="$(tr '\n' ',' < "$2")"; shift 2 ;;
      --out) out="$2"; shift 2 ;;
      --max-console) maxc="$2"; shift 2 ;;
      --structure) structure="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [ -n "$base" ] || { echo "usage: agent-browser.sh audit <base-url> (--paths a,b,c | --paths-file f) [--out dir] [--max-console N] [--structure strict|optional]" >&2; return 3; }
  case "$structure" in strict|optional) ;; *) echo "audit: --structure must be 'strict' or 'optional' (got '$structure')" >&2; return 3 ;; esac
  [ -n "$paths" ] || paths="/"
  require_primary audit || return $?

  mkdir -p "$out/shots"
  local chrome; chrome="$(resolve_chrome 2>/dev/null || true)"; [ -n "$chrome" ] && export AGENT_BROWSER_EXECUTABLE_PATH="$chrome"
  local bin; bin="$(ab_bin)"
  reset_daemon

  local results="[]" total=0 flagged=0
  local IFS=','
  for p in $paths; do
    [ -n "$p" ] || continue
    local url label
    url="${base%/}/${p#/}"
    label="$(printf '%s' "$p" | sed -E 's#^/+##; s#/+$##; s#[/]+#-#g')"; [ -n "$label" ] || label="root"
    audit_line "audit" "open" "$url" "read-only" "allow" "audit-sweep"
    "$bin" open "$url" >/dev/null 2>&1; sleep 1
    local snap console vitals tree
    snap="$(timeout 15 "$bin" snapshot --json 2>/dev/null)"
    console="$(timeout 15 "$bin" console --json 2>/dev/null)"
    vitals="$(timeout 20 "$bin" vitals --json 2>/dev/null)"
    "$bin" screenshot "$out/shots/$label.png" >/dev/null 2>&1
    # responsive overflow probe (advisory): screenshot + scrollWidth>clientWidth at
    # 375px and 1280px. The eval expression is FIXED/internal (no user input) — the
    # documented OQ2 mechanism; it never flows through the policy-gated `run` path.
    local ov_expr='document.documentElement.scrollWidth > document.documentElement.clientWidth'
    local ov375 ov1280
    "$bin" set viewport 375 812 >/dev/null 2>&1
    "$bin" screenshot "$out/shots/$label-375.png" >/dev/null 2>&1
    ov375="$("$bin" eval "$ov_expr" --json 2>/dev/null | jq -r '.data.result // false' 2>/dev/null || echo false)"
    "$bin" set viewport 1280 800 >/dev/null 2>&1
    "$bin" screenshot "$out/shots/$label-1280.png" >/dev/null 2>&1
    ov1280="$("$bin" eval "$ov_expr" --json 2>/dev/null | jq -r '.data.result // false' 2>/dev/null || echo false)"
    case "$ov375" in true|false) ;; *) ov375=false ;; esac
    case "$ov1280" in true|false) ;; *) ov1280=false ;; esac
    tree="$(printf '%s' "$snap" | jq -r '.data.snapshot // ""' 2>/dev/null)"
    eval "$(parse_structure "$tree")"   # sets h1 h2 main nav (shell eval, not browser eval)
    local cerr lcp cls flags=""
    cerr="$(printf '%s' "$console" | jq '[.data.messages[]? | select(.type=="error")] | length' 2>/dev/null || echo 0)"
    lcp="$(printf '%s' "$vitals" | jq -r '(.data.lcp.startTime // 0) | floor' 2>/dev/null || echo 0)"
    cls="$(printf '%s' "$vitals" | jq -r '.data.cls.score // 0' 2>/dev/null || echo 0)"
    # advisory flags (recorded in both modes; gating differs by --structure below)
    [ "${h1:-0}" != "1" ] && flags="${flags}h1=${h1}$([ "$structure" = optional ] && echo '(adv)') "
    [ "${main:-0}" = "0" ] && flags="${flags}no-main$([ "$structure" = optional ] && echo '(adv)') "
    [ "${nav:-0}" = "0" ] && flags="${flags}no-nav "
    [ "${cerr:-0}" -gt "${maxc:-0}" ] 2>/dev/null && flags="${flags}console=${cerr} "
    [ "$ov375" = "true" ] && flags="${flags}overflow@375 "
    [ "$ov1280" = "true" ] && flags="${flags}overflow@1280 "
    # gate: strict = h1+main+console (152.1, unchanged); optional = console only
    # (h1/main advisory). Overflow is advisory in BOTH modes.
    local ok=true
    if [ "$structure" = "strict" ]; then
      { [ "${h1:-0}" = "1" ] && [ "${main:-0}" = "1" ] && [ "${cerr:-0}" -le "${maxc:-0}" ]; } || ok=false
    else
      { [ "${cerr:-0}" -le "${maxc:-0}" ]; } || ok=false
    fi
    [ "$ok" = true ] || flagged=$((flagged+1))
    total=$((total+1))
    results="$(jq -c --arg l "$label" --arg u "$url" --argjson h1 "${h1:-0}" --argjson main "${main:-0}" \
      --argjson nav "${nav:-0}" --argjson cerr "${cerr:-0}" --argjson lcp "${lcp:-0}" --arg cls "${cls:-0}" \
      --argjson ov375 "$ov375" --argjson ov1280 "$ov1280" --arg mode "$structure" \
      --argjson ok "$ok" --arg flags "${flags:-—}" \
      '. + [{label:$l,url:$u,h1:$h1,main:$main,nav:$nav,console_errors:$cerr,lcp_ms:$lcp,cls:($cls|tonumber? // 0),overflow_375:$ov375,overflow_1280:$ov1280,structure_mode:$mode,ok:$ok,flags:$flags}]' <<<"$results")"
    echo "  $([ "$ok" = true ] && echo ✓ || echo ✗) $label (h1=${h1} main=${main} nav=${nav} console=${cerr} lcp=${lcp}ms overflow:375=${ov375}/1280=${ov1280}) ${flags}"
  done
  reset_daemon

  jq -cn --argjson results "$results" --argjson total "$total" --argjson flagged "$flagged" \
    '{total:$total,flagged:$flagged,pages:$results}' > "$out/report.json"
  {
    echo "_structure mode: \`$structure\` — $([ "$structure" = strict ] && echo 'gate = h1==1 & main & console≤max' || echo 'gate = console≤max; h1/main advisory'). Overflow + vitals advisory._"
    echo
    echo "| page | h1 | main | nav | console-err | overflow 375 | overflow 1280 | LCP ms | CLS | flags |"
    echo "|---|---|---|---|---|---|---|---|---|---|"
    jq -r '.pages[] | "| \(.label) | \(.h1) | \(if .main==1 then "Y" else "N" end) | \(if .nav==1 then "Y" else "N" end) | \(.console_errors) | \(if .overflow_375 then "⚠Y" else "N" end) | \(if .overflow_1280 then "⚠Y" else "N" end) | \(.lcp_ms) | \(.cls) | \(.flags) |"' "$out/report.json"
  } > "$out/report.md"
  echo "AUDIT[$structure]: $total pages, $flagged flagged → $out/report.md (overflow + vitals advisory; vitals meaningful only vs a deployed/throttled target)"
  [ "$flagged" -eq 0 ]
}

# --- dispatch ---------------------------------------------------------------
case "${1:-help}" in
  caps)            shift; caps "$@" ;;
  route)           shift; route "$@" ;;
  policy-eval)     shift
                   [ "$#" -ge 1 ] || { echo "usage: policy-eval <action> <target> [--confirm]" >&2; exit 3; }
                   out="$(policy_eval "$@")"; rc=$?; printf '%s\n' "$out" | tr '\t' ' '; exit $rc ;;
  run)             shift; run "$@" ;;
  reset)           reset_daemon; echo "daemon reset" ;;
  verify-contract) shift; verify_contract "$@" ;;
  audit)           shift; audit_pages "$@" ;;
  adopt)           shift; adopt_session "$@" ;;
  parse-structure) shift; parse_structure "${1:-}" ;;
  audit-tail)      shift; n="${1:-20}"; f="$AUDIT_DIR/audit-$(date -u +%Y-%m-%d).jsonl"
                   [ -f "$f" ] && tail -n "$n" "$f" || echo "(no audit entries today)" ;;
  help|--help|-h)  sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//' ;;
  *)               echo "unknown subcommand: $1" >&2
                   echo "try: caps | route | policy-eval | run | verify-contract | audit-tail | help" >&2; exit 3 ;;
esac
