# system-config

Everything needed to turn a freshly installed machine into one I can work on,
in a single command. Written after losing a Neovim config I could not remember
how to rebuild.

```bash
git clone https://github.com/lanzarote0tr/system-config.git ~/system-config
cd ~/system-config && ./bootstrap.sh
```

Works on macOS, Arch, and Debian/Ubuntu. Safe to run twice — every step checks
before it acts, and anything it would overwrite is copied to `.backups/` first.
Add `--dry-run` to see the whole plan without changing a thing.

## The idea

Three things get lost when a machine dies, and each needs a different fix:

| What | Where it lives | How it comes back |
| --- | --- | --- |
| Which programs I use | `packages/manifest.psv` | `install/` resolves it per OS |
| How they are configured | `dotfiles/` | `scripts/link.sh` symlinks into `$HOME` |
| Which machine is which | `profiles/` | `--profile` picks the group set |

The manifest is the important part. It is one row per program, with a column
per platform, so *the list of what I use* is stored once instead of once per
distro:

```
neovim  | editor | brew:neovim | pacman:neovim | apt:neovim | primary editor
gh      | devtool| brew:gh     | pacman:github-cli | apt:gh  | apt needs the GitHub CLI repo
arc     | browser| cask:arc    | -             | -          | macOS only
hwp     | docs   | manual:...  | manual:...    | manual:...  |
```

`-` means genuinely unavailable — it is skipped in silence. `manual:` means no
package manager can do it; those are printed as a to-do list at the end of the
run, and `scripts/manual-todo.sh` reprints them any time.

## Layout

```
bootstrap.sh              entry point
lib/common.sh             logging, OS detection, dry-run plumbing
packages/
  manifest.psv            what to install, per platform     <- edit this
  resolve.sh              manifest + groups -> install list
  locks/                  what WAS installed, per machine   <- written by capture.sh
profiles/                 macbook, galaxybook, server, minimal
install/
  packages.sh             dispatcher; batches by manager, skips what is present
  macos.sh arch.sh ubuntu.sh    per-platform backends
  grub.sh                 install the GRUB theme (Arch/UEFI; --uninstall to revert)
dotfiles/<package>/       mirrors $HOME; nvim/.config/nvim/init.lua -> ~/.config/nvim/init.lua
system/grub/              Tokyo Night GRUB theme (system-level, not a dotfile)
  gen-assets.py           regenerates the PNGs; stdlib only, no ImageMagick
  theme/                  theme.txt + generated art (.pf2 fonts built at install)
scripts/
  link.sh                 symlink dotfiles into $HOME (stow-like, no dependency)
  post-link.sh            seed the per-machine .local files
  capture.sh              pull this machine's state back into the repo
  manual-todo.sh          list what has to be installed by hand
docs/DEPENDENCIES.md      the human-readable dependency list
```

## Manifest vs. lock

The manifest says *what I want*; it is curated and cross-platform. The lock
files say *what this machine actually had* — the full output of `brew leaves`,
`pacman -Qqe`, `apt-mark showmanual`, plus Neovim's `lazy-lock.json`. Refresh
them with:

```bash
./scripts/capture.sh
```

That is the command to run before wiping a machine, and occasionally in
between. It also pulls any dotfile that has drifted back into the repo, so a
config edited in a hurry at 2am is not lost. Review with `git diff` and commit.

## Machine-specific things

Tracked configs contain nothing with an absolute path, a secret, or a per-OS
answer. Those go in files that are created on first bootstrap and never
committed:

- `~/.zshrc.local`, `~/.zprofile.local`, `~/.zshenv.local`
- `~/.gitconfig.local` — includes the credential helper, which differs per OS

A dotfile package can also be gated to one platform by dropping a `.platform`
file next to it listing the OS families it applies to.

## Common tasks

```bash
./bootstrap.sh --dry-run                  # show the plan, change nothing
./bootstrap.sh -p server -y               # provision the home server
./bootstrap.sh --dotfiles-only            # just re-link configs
./bootstrap.sh -g core,editor             # a box I only need to edit files on
./scripts/link.sh --unlink nvim           # take the nvim symlinks back out
./scripts/capture.sh --locks-only         # snapshot installed packages
./scripts/manual-todo.sh arch             # what Arch still needs by hand
```

## Adding a program

1. Add it to `docs/DEPENDENCIES.md` with whatever it depends on.
2. Add a row to `packages/manifest.psv` with a name for each platform.
3. If it has config worth keeping, put it under `dotfiles/<name>/` mirroring
   its path relative to `$HOME`, then `./scripts/link.sh <name>`.

## What is deliberately not here

SSH keys, GPG private keys, `~/.config/gh/hosts.yml`, and anything else that
authenticates as me. Those are restored from a password manager or regenerated,
never from a git repository — `.gitignore` blocks the obvious shapes, but the
real defence is not putting them here.
