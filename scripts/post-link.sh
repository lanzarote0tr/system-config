#!/usr/bin/env bash
# Run after link.sh. Creates the per-machine files that the tracked dotfiles
# include but deliberately do not contain: anything with an absolute path, a
# per-OS answer, or a secret.
#
# Everything here is create-if-missing. It never overwrites your local edits.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
detect_os

DRY_RUN="${DRY_RUN:-0}"
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1
export DRY_RUN

# Create $1 with the heredoc on stdin, only if it does not exist yet.
seed() {
  local path="$1"
  if [ -e "$path" ]; then
    skip "$(basename "$path") already exists"
    cat >/dev/null
    return 0
  fi
  if [ "$DRY_RUN" = 1 ]; then
    printf '%s   $%s create %s\n' "$C_DIM" "$C_RESET" "$path"
    cat >/dev/null
    return 0
  fi
  cat > "$path"
  ok "created $(basename "$path")"
}

log "seeding per-machine config"

# ---------------------------------------------------------------- gitconfig
# The credential helper is the one git setting with a genuinely different
# answer on every OS, so it cannot live in the tracked .gitconfig.
case "$OS_FAMILY" in
  macos)  cred="osxkeychain" ;;
  arch)   cred="/usr/lib/git-core/git-credential-libsecret" ;;
  debian) cred="/usr/lib/git-core/git-credential-libsecret" ;;
  *)      cred="cache --timeout=3600" ;;
esac

seed "$HOME/.gitconfig.local" <<EOF
# Machine-specific git settings. Included by ~/.gitconfig; never committed.
[credential]
	helper = $cred

# Uncomment and point at a real path if you use a custom external differ:
# [diff]
# 	external = ~/.local/bin/sem-diff-wrapper
EOF

# -------------------------------------------------------------------- zsh
seed "$HOME/.zshrc.local" <<'EOF'
# Interactive shell settings that only make sense on THIS machine.
# Absolute paths to hand-installed tools, host-specific aliases, and so on.
#
# e.g.
# alias ghidra='$HOME/tools/ghidra/ghidraRun'
EOF

seed "$HOME/.zprofile.local" <<'EOF'
# PATH entries and exported variables that only exist on THIS machine.
EOF

seed "$HOME/.zshenv.local" <<'EOF'
# Environment for every zsh on THIS machine, interactive or not.
# Do not put secrets here if anything else can read your home directory.
EOF

# --------------------------------------------------- default applications
# xdg-open picks the first registered handler when nothing is set explicitly,
# which on a fresh Arch box means whichever browser landed in mimeinfo.cache
# first. Say it out loud instead. Not a symlinked dotfile: ~/.config/
# mimeapps.list also collects associations written by GUI apps at runtime.
if [ "$OS_FAMILY" != macos ] && have firefox; then
  if [ "$(xdg-settings get default-web-browser 2>/dev/null)" = firefox.desktop ]; then
    skip "default browser is already firefox"
  elif have xdg-settings; then
    run xdg-settings set default-web-browser firefox.desktop
    run xdg-mime default firefox.desktop \
      x-scheme-handler/http x-scheme-handler/https \
      text/html application/xhtml+xml
    ok "default browser -> firefox"
  fi
fi

# ------------------------------------------------------------------ shell
if [ "$SHELL" != "$(command -v zsh 2>/dev/null)" ] && have zsh; then
  warn "login shell is $SHELL, not zsh — change it with:"
  printf '        chsh -s %s\n' "$(command -v zsh)"
fi

# ------------------------------------------------------------------- dirs
for d in "$HOME/.local/bin" "$HOME/bin"; do
  [ -d "$d" ] || run mkdir -p "$d"
done

# -------------------------------------------------------------------- gpg
if have gpg && [ -d "$HOME/.gnupg" ]; then
  run chmod 700 "$HOME/.gnupg"
  find "$HOME/.gnupg" -type f -exec chmod 600 {} + 2>/dev/null || true
fi

ok "per-machine config ready"
