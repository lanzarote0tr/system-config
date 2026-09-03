#!/usr/bin/env bash
# Everything the manifest cannot install for you, on one platform.
#
#   scripts/manual-todo.sh [macos|arch|ubuntu] [groups]
#
# Defaults to this machine and every group.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
detect_os

column="${1:-$(manifest_column)}"
groups="${2:-all}"

log "manual installs for $column ($groups)"
"$REPO_ROOT/packages/resolve.sh" "$column" "$groups" \
  | awk -F'\t' '$1=="manual" {printf "  %-16s %s\n", $3, $2}'

printf '\n'
log "not available on $column at all"
awk -F'|' -v col="$( [ "$column" = macos ] && echo 3 || { [ "$column" = arch ] && echo 4 || echo 5; } )" '
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
NF == 6 && trim($col) == "-" {
  note = trim($6)
  printf "  %-16s %s\n", trim($1), (note == "" ? "" : note)
}' "$REPO_ROOT/packages/manifest.psv"
