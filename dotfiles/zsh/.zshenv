# .zshenv — read by EVERY zsh, including non-interactive ones spawned by
# scripts, editors and git hooks. Keep it tiny and side-effect free.

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R'

# Rust puts cargo/rustc on PATH here.
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

[ -f "$HOME/.zshenv.local" ] && . "$HOME/.zshenv.local"
