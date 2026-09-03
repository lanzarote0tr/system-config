#!/usr/bin/env bash
# Debian/Ubuntu backend: apt.

PLATFORM_MANAGERS="apt"

pm_prepare() {
  need_sudo
  export DEBIAN_FRONTEND=noninteractive
  log "updating apt lists"
  run $SUDO apt-get update -y
  run $SUDO apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg software-properties-common

  # The GitHub CLI is not in the default archives.
  if ! have gh && [ ! -f /etc/apt/sources.list.d/github-cli.list ]; then
    log "adding the GitHub CLI apt repository"
    if [ "${DRY_RUN:-0}" = 1 ]; then
      printf '%s   $%s add cli.github.com apt repo\n' "$C_DIM" "$C_RESET"
    else
      curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
      $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n' \
        "$(dpkg --print-architecture)" \
        | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
      $SUDO apt-get update -y
    fi
  fi
}

pm_installed() {
  case "$1" in
    apt) dpkg-query -W -f='${Package}\n' 2>/dev/null ;;
  esac
}

pm_install() {
  local mgr="$1"; shift
  case "$mgr" in
    apt) run $SUDO apt-get install -y "$@" ;;
  esac
}

pm_postinstall() {
  if have docker; then
    log "enabling docker and adding $USER to the docker group"
    run $SUDO systemctl enable --now docker.service || true
    run $SUDO usermod -aG docker "$USER" || true
    warn "log out and back in for docker group membership to take effect"
  fi
}
