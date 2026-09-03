#!/usr/bin/env bash
# Arch backend: pacman + an AUR helper (paru, bootstrapped if missing).

PLATFORM_MANAGERS="pacman aur"
AUR_HELPER=""

pm_prepare() {
  need_sudo
  log "syncing pacman databases"
  run $SUDO pacman -Syu --noconfirm

  # base-devel + git are needed to build anything from the AUR.
  run $SUDO pacman -S --needed --noconfirm base-devel git

  for h in paru yay; do
    if have "$h"; then AUR_HELPER="$h"; break; fi
  done

  if [ -z "$AUR_HELPER" ]; then
    log "bootstrapping paru (AUR helper)"
    local tmp
    tmp="$(mktemp -d)"
    run git clone --depth 1 https://aur.archlinux.org/paru-bin.git "$tmp/paru-bin"
    if [ "${DRY_RUN:-0}" = 1 ]; then
      printf '%s   $%s cd %s/paru-bin && makepkg -si --noconfirm\n' "$C_DIM" "$C_RESET" "$tmp"
    else
      ( cd "$tmp/paru-bin" && makepkg -si --noconfirm )
    fi
    rm -rf "$tmp"
    AUR_HELPER=paru
  fi
  ok "AUR helper: ${AUR_HELPER:-none}"
}

pm_installed() {
  case "$1" in
    pacman|aur) pacman -Qq 2>/dev/null ;;
  esac
}

pm_install() {
  local mgr="$1"; shift
  case "$mgr" in
    pacman) run $SUDO pacman -S --needed --noconfirm "$@" ;;
    aur)
      if [ -z "$AUR_HELPER" ]; then
        warn "no AUR helper; skipping: $*"
        return 0
      fi
      run "$AUR_HELPER" -S --needed --noconfirm "$@"
      ;;
  esac
}

pm_postinstall() {
  # Things that are a package on macOS but a service on Linux.
  if have docker; then
    log "enabling docker and adding $USER to the docker group"
    run $SUDO systemctl enable --now docker.service || true
    run $SUDO usermod -aG docker "$USER" || true
    warn "log out and back in for docker group membership to take effect"
  fi
}
