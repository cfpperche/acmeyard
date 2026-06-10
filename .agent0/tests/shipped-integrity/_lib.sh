#!/usr/bin/env bash
# Shared fixture builder for shipped-integrity scenarios.
# build_sandbox <dir>: minimal consumer tree with 2 shipped executables and
# 1 non-executable rule; echoes nothing. baseline_for writes the sha map.

set -euo pipefail
SUITE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT0_ROOT="${AGENT0_ROOT:-$(cd "$SUITE_DIR/../../.." && pwd)}"
DOCTOR="$AGENT0_ROOT/.agent0/tools/doctor.sh"

build_sandbox() {
  local d="$1"
  mkdir -p "$d/.agent0/hooks" "$d/.agent0/tools" "$d/.agent0/context/rules"
  printf '#!/usr/bin/env bash\necho hook\n' > "$d/.agent0/hooks/sample.sh"
  printf '#!/usr/bin/env bash\necho tool\n' > "$d/.agent0/tools/sample-tool.sh"
  printf '# a rule\n' > "$d/.agent0/context/rules/sample.md"
  chmod +x "$d/.agent0/hooks/sample.sh" "$d/.agent0/tools/sample-tool.sh"
}

sha_of() { sha256sum "$1" | awk '{print $1}'; }

write_baseline() { # write_baseline <sandbox> <rel:sha>...
  local d="$1"; shift
  {
    printf '{"files":{'
    local first=1 pair rel sha
    for pair in "$@"; do
      rel="${pair%%:*}"; sha="${pair#*:}"
      [ "$first" = 1 ] || printf ','
      printf '"%s":"%s"' "$rel" "$sha"
      first=0
    done
    printf '}}'
  } > "$d/.agent0/harness-sync-baseline.json"
}

doctor_section() { # doctor_section <sandbox> → prints the shipped-integrity section
  # Sandbox lacks core harness files, so doctor exits non-zero overall; this
  # suite asserts only the shipped-integrity section, hence the || true.
  AGENT0_PROJECT_DIR="$1" bash "$DOCTOR" 2>/dev/null | sed -n '/=== shipped integrity ===/,/^$/p' || true
}

assert_has() { # assert_has <haystack> <needle> <label>
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  PASS: $3"
  else
    echo "  FAIL: $3 (missing '$2')"; echo "$1" | sed 's/^/    | /'; exit 1
  fi
}

assert_not_has() {
  if printf '%s' "$1" | grep -qF -- "$2"; then
    echo "  FAIL: $3 (unexpected '$2')"; echo "$1" | sed 's/^/    | /'; exit 1
  else
    echo "  PASS: $3"
  fi
}
