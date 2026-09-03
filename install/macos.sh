#!/usr/bin/env bash
# macOS backend: Homebrew formulae + casks. Sourced by install/packages.sh.

PLATFORM_MANAGERS="brew cask"

pm_prepare() {
  if ! have brew; then
    log "installing Homebrew"
    run /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Make it usable for the rest of this run without a new login shell.
    for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      [ -x "$p" ] && eval "$("$p" shellenv)" && break
    done
  fi
  have brew || die "Homebrew is still not on PATH"

  if ! xcode-select -p >/dev/null 2>&1; then
    log "installing Command Line Tools (a GUI dialog will open)"
    run xcode-select --install || true
  fi

  log "updating Homebrew"
  run brew update
}

pm_installed() {
  case "$1" in
    brew) brew list --formula -1 2>/dev/null ;;
    cask) brew list --cask -1 2>/dev/null ;;
  esac
}

pm_install() {
  local mgr="$1"; shift
  case "$mgr" in
    brew) run brew install "$@" ;;
    cask) run brew install --cask "$@" ;;
  esac
}

pm_postinstall() {
  log "running brew cleanup"
  run brew cleanup
}
