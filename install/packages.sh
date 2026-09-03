#!/usr/bin/env bash
# Install everything the manifest selects for this machine.
#
#   install/packages.sh <groups>      e.g. "core,shell,editor" or "all"
#
# Expects lib/common.sh to be sourced and detect_os() to have run.
# Written for bash 3.2 (what macOS ships) — no associative arrays.
set -euo pipefail

# ---------------------------------------------------------- cross-platform
# Managers that work the same everywhere, so they live here instead of in
# the per-platform backends.

xpm_installed() {
  case "$1" in
    npm)  npm ls -g --depth=0 --parseable 2>/dev/null \
            | sed 's|.*/node_modules/||' | grep -v '^/' || true ;;
    pipx) pipx list --short 2>/dev/null | awk '{print $1}' || true ;;
    go)   ls "${GOBIN:-${GOPATH:-$HOME/go}/bin}" 2>/dev/null || true ;;
  esac
}

xpm_install() {
  local mgr="$1"; shift
  case "$mgr" in
    npm)
      have npm || { warn "npm not available yet; skipping: $*"; return 0; }
      run npm install -g "$@"
      ;;
    pipx)
      have pipx || { warn "pipx not available yet; skipping: $*"; return 0; }
      local p; for p in "$@"; do run pipx install "$p"; done
      ;;
    go)
      have go || { warn "go not available yet; skipping: $*"; return 0; }
      local p; for p in "$@"; do run go install "$p"; done
      ;;
  esac
}

# A go: cell is an import path; the installed binary is the last path segment
# with any /vN and @version stripped.
go_binary_name() {
  printf '%s' "$1" | sed -e 's/@.*$//' -e 's|/v[0-9]\+$||' -e 's|.*/||'
}

# ------------------------------------------------------------------- main
install_packages() {
  local groups="${1:-all}"
  local column; column="$(manifest_column)"

  # shellcheck source=/dev/null
  case "$OS_FAMILY" in
    macos)  . "$REPO_ROOT/install/macos.sh"  ;;
    arch)   . "$REPO_ROOT/install/arch.sh"   ;;
    debian) . "$REPO_ROOT/install/ubuntu.sh" ;;
    *) die "no install backend for OS family '$OS_FAMILY'" ;;
  esac

  local records
  records="$("$REPO_ROOT/packages/resolve.sh" "$column" "$groups")" \
    || die "manifest failed to resolve"

  if [ -z "$records" ]; then
    warn "no packages selected for groups '$groups' on $column"
    return 0
  fi

  log "preparing package managers on $OS_ID ($OS_ARCH)"
  pm_prepare

  local mgr
  for mgr in $PLATFORM_MANAGERS npm pipx go; do
    local wanted
    wanted="$(printf '%s\n' "$records" \
      | awk -F'\t' -v m="$mgr" '$1==m {print $2}' \
      | tr ' ' '\n' | sed '/^$/d' | sort -u)"
    [ -z "$wanted" ] && continue

    local installed missing
    case "$mgr" in
      npm|pipx|go) installed="$(xpm_installed "$mgr" | sort -u)" ;;
      *)           installed="$(pm_installed "$mgr" | sort -u)" ;;
    esac

    if [ "$mgr" = go ]; then
      # Compare on binary name, install by import path.
      missing=''
      local path bin
      while IFS= read -r path; do
        [ -z "$path" ] && continue
        bin="$(go_binary_name "$path")"
        printf '%s\n' "$installed" | grep -qx "$bin" || missing="$missing$path"$'\n'
      done <<< "$wanted"
      missing="$(printf '%s' "$missing" | sed '/^$/d')"
    else
      missing="$(comm -13 <(printf '%s\n' "$installed") <(printf '%s\n' "$wanted"))"
    fi

    local n_want n_miss
    n_want="$(printf '%s\n' "$wanted" | sed '/^$/d' | wc -l | tr -d ' ')"
    if [ -z "$missing" ]; then
      skip "$mgr: all $n_want already installed"
      continue
    fi
    n_miss="$(printf '%s\n' "$missing" | sed '/^$/d' | wc -l | tr -d ' ')"

    log "$mgr: installing $n_miss of $n_want"
    case "$mgr" in
      npm|pipx|go) xpm_install "$mgr" $missing ;;
      *)           pm_install  "$mgr" $missing ;;
    esac
  done

  if declare -f pm_postinstall >/dev/null; then
    pm_postinstall
  fi

  # ------------------------------------------------------- manual leftovers
  local manual
  manual="$(printf '%s\n' "$records" | awk -F'\t' '$1=="manual" {print $3"\t"$2}')"
  if [ -n "$manual" ]; then
    printf '\n%s==> install by hand%s (no package manager on %s):\n' \
      "$C_YELLOW" "$C_RESET" "$column"
    printf '%s\n' "$manual" | while IFS=$'\t' read -r id how; do
      printf '    %-18s %s\n' "$id" "$how"
    done
    printf '\n'
  fi

  ok "packages done"
}
