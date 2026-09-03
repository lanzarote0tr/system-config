#!/usr/bin/env bash
# Resolve the manifest for one platform + one set of groups.
#
#   resolve.sh <macos|arch|ubuntu> <group,group,...>
#
# Prints one record per selected package, tab separated:
#
#   <manager>\t<packages>\t<id>\t<note>
#
# Rows whose cell is "-" are dropped. "all" as the group list selects everything.
set -euo pipefail

MANIFEST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/manifest.psv"
column="${1:?usage: resolve.sh <macos|arch|ubuntu> <groups>}"
groups="${2:-all}"

case "$column" in
  macos)  col=3 ;;
  arch)   col=4 ;;
  ubuntu) col=5 ;;
  *) printf 'resolve.sh: unknown platform column %s\n' "$column" >&2; exit 2 ;;
esac

awk -F'|' -v col="$col" -v want="$groups" '
function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

BEGIN {
  n = split(want, w, /,/)
  for (i = 1; i <= n; i++) {
    g = trim(w[i])
    if (g == "all") all = 1
    else if (g != "") wanted[g] = 1
  }
}

/^[[:space:]]*#/ { next }
/^[[:space:]]*$/ { next }

NF != 6 {
  printf("resolve.sh: %s:%d has %d fields, expected 6\n", FILENAME, FNR, NF) > "/dev/stderr"
  bad = 1
  next
}

{
  id   = trim($1)
  cell = trim($col)
  note = trim($6)
  if (cell == "" || cell == "-") next

  if (!all) {
    keep = 0
    m = split(trim($2), gs, /,/)
    for (i = 1; i <= m; i++) if (trim(gs[i]) in wanted) keep = 1
    if (!keep) next
  }

  sep = index(cell, ":")
  if (sep == 0) {
    printf("resolve.sh: %s: cell for id \"%s\" has no <manager>: prefix\n", FILENAME, id) > "/dev/stderr"
    bad = 1
    next
  }
  mgr  = substr(cell, 1, sep - 1)
  pkgs = trim(substr(cell, sep + 1))
  gsub(/%%/, "|", pkgs)
  gsub(/%%/, "|", note)
  if (pkgs == "") next

  printf("%s\t%s\t%s\t%s\n", mgr, pkgs, id, note)
}

END { if (bad) exit 3 }
' "$MANIFEST"
