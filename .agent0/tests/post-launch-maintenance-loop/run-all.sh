#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$DIR/01-surface-and-placeholders.sh"
"$DIR/02-provider-neutrality.sh"
