#!/usr/bin/env bash
# Shared helpers. Sourced by bootstrap.sh and everything under install/ and scripts/.

# ---------------------------------------------------------------- repo layout
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT

# ------------------------------------------------------------------- logging
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
else
  C_RESET=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''
fi

log()   { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip()  { printf '%sskip%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn()  { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()   { printf '%s err%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

# Echo a command instead of running it when DRY_RUN=1.
run() {
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '%s   $%s %s\n' "$C_DIM" "$C_RESET" "$*"
  else
    "$@"
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------- OS detection
# Sets: OS_ID (macos|arch|ubuntu|debian|...), OS_FAMILY (macos|arch|debian),
#       OS_ARCH (arm64|x86_64)
detect_os() {
  OS_ARCH="$(uname -m)"
  case "$(uname -s)" in
    Darwin)
      OS_ID=macos
      OS_FAMILY=macos
      ;;
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        OS_ID="$(. /etc/os-release && printf '%s' "$ID")"
        local like
        like="$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")"
        case "$OS_ID $like" in
          *arch*)            OS_FAMILY=arch ;;
          *debian*|*ubuntu*) OS_FAMILY=debian ;;
          *)                 OS_FAMILY="$OS_ID" ;;
        esac
      else
        OS_ID=linux; OS_FAMILY=linux
      fi
      ;;
    *) die "unsupported kernel: $(uname -s)" ;;
  esac
  export OS_ID OS_FAMILY OS_ARCH
}

# The manifest column to read for this machine.
manifest_column() {
  case "$OS_FAMILY" in
    macos)  printf 'macos'  ;;
    arch)   printf 'arch'   ;;
    debian) printf 'ubuntu' ;;
    *)      die "no manifest column for OS family '$OS_FAMILY'" ;;
  esac
}

# ------------------------------------------------------------------ sudo
# Ask once, keep the timestamp warm for the rest of the run.
SUDO=''
need_sudo() {
  [ "$(id -u)" = 0 ] && { SUDO=''; return 0; }
  have sudo || die "sudo is required but not installed"
  SUDO=sudo
  [ "${DRY_RUN:-0}" = 1 ] && return 0
  sudo -v || die "sudo authentication failed"
  # Refresh in the background until this script exits.
  while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
}
