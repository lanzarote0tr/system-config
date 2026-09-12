# .zshrc — interactive shells only.

# ------------------------------------------------------------------ prompt
PROMPT='%F{cyan}%n@%m%f %F{yellow}%~%f %# '

# ------------------------------------------------------------- completion
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'   # case-insensitive
autoload -Uz compinit && compinit -C

# ---------------------------------------------------------------- history
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY EXTENDED_HISTORY

# ----------------------------------------------------------------- aliases
# GNU ls takes --color, BSD/macOS ls takes -G. Pick whichever this box has.
if ls --color=auto . >/dev/null 2>&1; then
  alias ls='ls --color=auto'
else
  alias ls='ls -G'
fi
alias ll='ls -hal'
alias l='ll'
alias a='ls -al'
alias grep='grep --color=auto'

alias vim='nvim'
alias gt='git log --graph --oneline'

# Backlight control. Path is specific to machines with an eDP-1 panel on
# card1 (e.g. Intel iGPU laptops) — harmless no-op elsewhere since the path
# just won't exist.
alias b='sudo vim /sys/devices/pci0000:00/0000:00:02.0/drm/card1/card1-eDP-1/intel_backlight/brightness'

# Homebrew's GCC is versioned; alias to it only when it is actually installed.
for _v in 16 15 14 13; do
  if command -v "gcc-$_v" >/dev/null 2>&1; then
    alias gcc="gcc-$_v" "g++=g++-$_v"
    break
  fi
done
unset _v

# --------------------------------------------------------------- functions
mcd() { mkdir -p "$1" && cd "$1"; }

rgl() { rg --color=always --heading --line-number "$@" | less -R; }

# ------------------------------------------------------------------- gpg
# Needed for pinentry to find the terminal when signing commits.
export GPG_TTY="$(tty)"

# ----------------------------------------------------------------- python
if command -v pyenv >/dev/null 2>&1; then
  export PYENV_ROOT="${PYENV_ROOT:-$HOME/.pyenv}"
  case ":$PATH:" in *":$PYENV_ROOT/bin:"*) ;; *) PATH="$PYENV_ROOT/bin:$PATH" ;; esac
  eval "$(pyenv init - --path)"
  eval "$(pyenv init -)"
fi

# conda, if miniforge/miniconda is installed. Kept lazy: sourcing the hook on
# every shell costs ~100ms, so only do it when the profile script exists.
for _conda in \
  /opt/homebrew/Caskroom/miniforge/base/etc/profile.d/conda.sh \
  "$HOME/miniforge3/etc/profile.d/conda.sh" \
  "$HOME/miniconda3/etc/profile.d/conda.sh" \
  /opt/conda/etc/profile.d/conda.sh
do
  if [ -f "$_conda" ]; then . "$_conda"; break; fi
done
unset _conda

# ------------------------------------------------------------------- bun
[ -s "$HOME/.bun/_bun" ] && . "$HOME/.bun/_bun"

# ---------------------------------------------------------------- plugins
# zsh-autosuggestions lives in a different place on every distro.
for _sug in \
  "${HOMEBREW_PREFIX:-/opt/homebrew}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
do
  if [ -f "$_sug" ]; then . "$_sug"; break; fi
done
unset _sug

# z — directory jumping.
for _z in \
  "${HOMEBREW_PREFIX:-/opt/homebrew}/etc/profile.d/z.sh" \
  /usr/share/z/z.sh \
  /etc/profile.d/z.sh
do
  if [ -f "$_z" ]; then . "$_z"; break; fi
done
unset _z

# fzf keybindings (ctrl-r, ctrl-t). Newer fzf ships `fzf --zsh`.
if command -v fzf >/dev/null 2>&1; then
  if fzf --zsh >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
  else
    [ -f "$HOME/.fzf.zsh" ] && . "$HOME/.fzf.zsh"
  fi
fi

# ------------------------------------------------------------------ local
# Anything that only makes sense on ONE machine — absolute paths to tools,
# work secrets, per-host aliases — goes here. Not tracked by system-config.
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
