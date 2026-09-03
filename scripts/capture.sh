#!/usr/bin/env bash
# The reverse of link.sh: pull this machine's current state back into the repo
# so it can never be lost again.
#
#   scripts/capture.sh [--dry-run] [--dotfiles-only] [--locks-only]
#
# Two things get captured:
#   1. dotfiles  — any tracked file that exists in $HOME as a real file (i.e.
#                  it drifted, or was never linked) is copied back over the
#                  repo's copy. Correct symlinks are left alone.
#   2. locks     — a full snapshot of what is actually installed, per manager,
#                  into packages/locks/<manager>.<hostname>. The manifest says
#                  what you want; the locks record what you had.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
detect_os

DRY_RUN="${DRY_RUN:-0}"
DO_DOTFILES=1
DO_LOCKS=1

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n)    DRY_RUN=1 ;;
    --dotfiles-only) DO_LOCKS=0 ;;
    --locks-only)    DO_DOTFILES=0 ;;
    -h|--help) sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done
export DRY_RUN

# Everything this script writes lands in the git working tree, so a bad capture
# is always undone with `git checkout -- .` — but only if there was nothing
# uncommitted to begin with. Say so up front.
if [ "$DRY_RUN" != 1 ] && ! git -C "$REPO_ROOT" diff --quiet 2>/dev/null; then
  warn "the repo already has uncommitted changes; capture will mix into them"
fi

HOST="$(hostname -s 2>/dev/null || uname -n)"
LOCKS="$REPO_ROOT/packages/locks"

# ------------------------------------------------------------------ dotfiles
capture_dotfiles() {
  local changed=0 pkg src file rel target
  for src in "$REPO_ROOT"/dotfiles/*/; do
    src="${src%/}"
    pkg="$(basename "$src")"
    while IFS= read -r file; do
      rel="${file#"$src"/}"
      [ "$rel" = ".platform" ] && continue
      target="$HOME/$rel"

      [ -e "$target" ] || continue
      # A correct symlink means the repo copy IS the live copy.
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
        continue
      fi
      if cmp -s "$target" "$file"; then
        continue
      fi
      warn "$pkg: ~/$rel differs from the repo copy"
      run cp "$target" "$file"
      changed=$((changed + 1))
    done < <(find "$src" -type f | sort)
  done
  if [ "$changed" -eq 0 ]; then
    ok "dotfiles: no drift"
  else
    log "dotfiles: pulled $changed file(s) back into the repo"
  fi
}

# --------------------------------------------------------------------- locks
write_lock() {
  local name="$1"; shift
  local out="$LOCKS/$name"
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s   $%s %s > packages/locks/%s\n' "$C_DIM" "$C_RESET" "$*" "$name"
    return 0
  fi
  mkdir -p "$LOCKS"
  {
    printf '# %s — captured %s on %s (%s)\n' "$name" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOST" "$OS_ID"
    "$@"
  } > "$out"
  ok "packages/locks/$name ($(grep -cv '^#' "$out") entries)"
}

capture_locks() {
  case "$OS_FAMILY" in
    macos)
      if have brew; then
        write_lock "brew-formulae.$HOST" brew leaves --installed-on-request
        write_lock "brew-casks.$HOST"    brew list --cask -1
        write_lock "brew-taps.$HOST"     brew tap
      fi
      ;;
    arch)
      have pacman && write_lock "pacman.$HOST" pacman -Qqe
      ;;
    debian)
      have apt-mark && write_lock "apt.$HOST" apt-mark showmanual
      ;;
  esac

  have npm  && write_lock "npm.$HOST"  sh -c \
    'npm ls -g --depth=0 --parseable 2>/dev/null | sed "s|.*/node_modules/||" | grep -v "^/"'
  have pipx && write_lock "pipx.$HOST" sh -c 'pipx list --short 2>/dev/null'

  # Neovim pins its own plugin versions; make sure the repo has the live file.
  if [ -f "$HOME/.config/nvim/lazy-lock.json" ]; then
    if ! cmp -s "$HOME/.config/nvim/lazy-lock.json" \
                "$REPO_ROOT/dotfiles/nvim/.config/nvim/lazy-lock.json"; then
      run cp "$HOME/.config/nvim/lazy-lock.json" \
             "$REPO_ROOT/dotfiles/nvim/.config/nvim/lazy-lock.json"
      ok "refreshed nvim lazy-lock.json"
    fi
  fi
}

[ "$DO_DOTFILES" = 1 ] && { log "capturing dotfiles"; capture_dotfiles; }
[ "$DO_LOCKS" = 1 ]    && { log "capturing installed-package locks"; capture_locks; }

log "done — review with 'git diff' before committing"
