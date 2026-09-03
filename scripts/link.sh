#!/usr/bin/env bash
# Symlink dotfiles/<package>/** into $HOME, GNU-stow style but with no
# dependency on stow (a fresh box has neither stow nor perl guaranteed).
#
#   scripts/link.sh [--dry-run] [--force] [--unlink] [package ...]
#
# Layout rule: everything under dotfiles/<package>/ mirrors its path relative
# to $HOME. So dotfiles/nvim/.config/nvim/init.lua -> ~/.config/nvim/init.lua.
#
# A package may contain a `.platform` file listing the OS families it applies
# to (one per line: macos, arch, debian). Packages gated to another platform
# are skipped.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
detect_os

DRY_RUN="${DRY_RUN:-0}"
FORCE=0
UNLINK=0
PACKAGES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --force|-f)   FORCE=1 ;;
    --unlink|-u)  UNLINK=1 ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)  PACKAGES+=("$1") ;;
  esac
  shift
done
export DRY_RUN

DOTFILES="$REPO_ROOT/dotfiles"
BACKUP_DIR="$REPO_ROOT/.backups/$(date +%Y%m%d-%H%M%S)"

if [ "${#PACKAGES[@]}" -eq 0 ]; then
  while IFS= read -r d; do PACKAGES+=("$(basename "$d")"); done \
    < <(find "$DOTFILES" -mindepth 1 -maxdepth 1 -type d | sort)
fi

platform_allows() {
  local gate="$1/.platform"
  [ -f "$gate" ] || return 0
  grep -qx "$OS_FAMILY" "$gate"
}

backup() {
  local target="$1" rel="${1#"$HOME"/}"
  run mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  run mv "$target" "$BACKUP_DIR/$rel"
  warn "backed up existing $rel -> .backups/$(basename "$BACKUP_DIR")/$rel"
}

linked=0; skipped=0; replaced=0; removed=0

for pkg in "${PACKAGES[@]}"; do
  src="$DOTFILES/$pkg"
  [ -d "$src" ] || die "no such dotfiles package: $pkg"

  if ! platform_allows "$src"; then
    skip "$pkg (gated to $(tr '\n' ' ' < "$src/.platform" | sed 's/ $//'), this is $OS_FAMILY)"
    continue
  fi

  while IFS= read -r file; do
    rel="${file#"$src"/}"
    [ "$rel" = ".platform" ] && continue
    target="$HOME/$rel"

    if [ "$UNLINK" = 1 ]; then
      if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
        run rm "$target"
        ok "unlinked ~/$rel"
        removed=$((removed + 1))
      fi
      continue
    fi

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$file" ]; then
      skipped=$((skipped + 1))
      continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ "$FORCE" = 1 ]; then
        run rm -rf "$target"
      else
        backup "$target"
      fi
      replaced=$((replaced + 1))
    else
      linked=$((linked + 1))
    fi

    run mkdir -p "$(dirname "$target")"
    run ln -s "$file" "$target"
    ok "~/$rel -> dotfiles/$pkg/$rel"
  done < <(find "$src" -type f -o -type l | sort)
done

if [ "$UNLINK" = 1 ]; then
  log "removed $removed symlink(s)"
else
  log "linked $linked, replaced $replaced, already correct $skipped"
  [ -d "$BACKUP_DIR" ] && log "backups in .backups/$(basename "$BACKUP_DIR")"
fi
