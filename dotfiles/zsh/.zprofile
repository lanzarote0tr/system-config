# .zprofile — login shells. PATH and environment only; no aliases, no prompt.

# ---------------------------------------------------------------- homebrew
# Apple Silicon, Intel macOS, and Linuxbrew respectively.
for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
done
unset _brew

# -------------------------------------------------------------------- PATH
# Add a directory only if it exists and is not already there, so re-sourcing
# this file (or nesting login shells) cannot grow PATH without bound.
_path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) [ -d "$1" ] && PATH="$1:$PATH" ;;
  esac
}

_path_prepend "$HOME/go/bin"
_path_prepend "$HOME/flutter/bin"
_path_prepend "$HOME/.bun/bin"
_path_prepend "$HOME/.local/bin"
_path_prepend "$HOME/bin"
export PATH

export BUN_INSTALL="$HOME/.bun"
export GOPATH="${GOPATH:-$HOME/go}"

# --------------------------------------------------------------- terminal
# Free up C-s / C-q so they can be used as key bindings instead of flow control.
case $- in *i*) stty -ixon 2>/dev/null ;; esac

# --------------------------------------------------------------- OrbStack
[ -f "$HOME/.orbstack/shell/init.zsh" ] && . "$HOME/.orbstack/shell/init.zsh" 2>/dev/null

# Machine-specific PATH entries live here and are never committed.
[ -f "$HOME/.zprofile.local" ] && . "$HOME/.zprofile.local"
