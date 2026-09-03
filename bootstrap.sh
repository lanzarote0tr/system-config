#!/usr/bin/env bash
#
#   system-config — take a freshly installed machine to a working one.
#
#   ./bootstrap.sh [options]
#
#   -p, --profile NAME   which machine this is: macbook | galaxybook | server
#                        | minimal  (default: guessed from the OS)
#   -g, --groups LIST    install these manifest groups instead of the profile's
#                        (e.g. --groups core,editor). "all" selects everything.
#       --packages-only  install packages, do not touch dotfiles
#       --dotfiles-only  link dotfiles, do not install anything
#   -n, --dry-run        print every command instead of running it
#   -y, --yes            do not ask for confirmation
#   -h, --help           this message
#
# Safe to re-run: every step checks before it acts, and link.sh backs up any
# file it is about to replace into .backups/.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$REPO_ROOT/lib/common.sh"

PROFILE=""
SELECTED_GROUPS=""
DO_PACKAGES=1
DO_DOTFILES=1
DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES=0

while [ $# -gt 0 ]; do
  case "$1" in
    -p|--profile)  PROFILE="${2:?--profile needs a name}"; shift ;;
    -g|--groups)   SELECTED_GROUPS="${2:?--groups needs a list}"; shift ;;
    --packages-only) DO_DOTFILES=0 ;;
    --dotfiles-only) DO_PACKAGES=0 ;;
    -n|--dry-run)  DRY_RUN=1 ;;
    -y|--yes)      ASSUME_YES=1 ;;
    -h|--help)     sed -n '2,20p' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) die "unknown option: $1  (try --help)" ;;
  esac
  shift
done
export DRY_RUN

detect_os

# ------------------------------------------------------------------ profile
if [ -z "$PROFILE" ]; then
  case "$OS_FAMILY" in
    macos)  PROFILE=macbook ;;
    arch)   PROFILE=galaxybook ;;
    debian) PROFILE=server ;;
    *)      PROFILE=minimal ;;
  esac
fi
PROFILE_FILE="$REPO_ROOT/profiles/$PROFILE.conf"
[ -f "$PROFILE_FILE" ] || die "no such profile: $PROFILE (see profiles/)"

if [ -z "$SELECTED_GROUPS" ]; then
  SELECTED_GROUPS="$(grep -v '^[[:space:]]*#' "$PROFILE_FILE" \
            | sed '/^[[:space:]]*$/d' | tr -d ' ' | paste -sd, -)"
fi

# -------------------------------------------------------------------- plan
printf '\n'
log "system-config"
printf '    machine   %s (%s, %s)\n' "$(hostname -s 2>/dev/null || uname -n)" "$OS_ID" "$OS_ARCH"
printf '    profile   %s\n' "$PROFILE"
printf '    groups    %s\n' "$SELECTED_GROUPS"
printf '    packages  %s\n' "$([ "$DO_PACKAGES" = 1 ] && echo yes || echo 'skipped')"
printf '    dotfiles  %s\n' "$([ "$DO_DOTFILES" = 1 ] && echo yes || echo 'skipped')"
[ "$DRY_RUN" = 1 ] && printf '    mode      %sdry run — nothing will change%s\n' "$C_YELLOW" "$C_RESET"
printf '\n'

if [ "$ASSUME_YES" != 1 ] && [ "$DRY_RUN" != 1 ]; then
  printf 'Continue? [y/N] '
  read -r reply
  case "$reply" in [yY]*) ;; *) die "aborted" ;; esac
fi

# ---------------------------------------------------------------- packages
if [ "$DO_PACKAGES" = 1 ]; then
  . "$REPO_ROOT/install/packages.sh"
  install_packages "$SELECTED_GROUPS"
fi

# ---------------------------------------------------------------- dotfiles
if [ "$DO_DOTFILES" = 1 ]; then
  log "linking dotfiles"
  "$REPO_ROOT/scripts/link.sh" $([ "$DRY_RUN" = 1 ] && echo --dry-run)
  "$REPO_ROOT/scripts/post-link.sh"
fi

printf '\n'
ok "bootstrap complete"
printf '    open a new shell, then run: %snvim%s (lazy.nvim installs plugins on first start)\n' \
  "$C_BLUE" "$C_RESET"
printf '    still to do by hand: %sscripts/manual-todo.sh%s\n\n' "$C_BLUE" "$C_RESET"
