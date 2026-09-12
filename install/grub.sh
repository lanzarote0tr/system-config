#!/usr/bin/env bash
# Install the Tokyo Night GRUB theme from system/grub/.
#
#   install/grub.sh [--dry-run] [--no-regen] [--uninstall]
#
# Builds the .pf2 fonts with grub-mkfont, stages the theme into
# /boot/grub/themes/<name>, points GRUB_THEME at it and regenerates grub.cfg.
# The previous /etc/default/grub and grub.cfg are backed up next to
# themselves with a .bak-<timestamp> suffix before anything is touched.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"
detect_os

DRY_RUN="${DRY_RUN:-0}"
REGEN=1
UNINSTALL=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1 ;;
    --no-regen)   REGEN=0 ;;
    --uninstall)  UNINSTALL=1 ;;
    -h|--help)    sed -n '2,11p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'; exit 0 ;;
    *)            die "unknown option: $1" ;;
  esac
  shift
done
export DRY_RUN

THEME_NAME=tokyonight
SRC="$REPO_ROOT/system/grub/theme"
DEST="/boot/grub/themes/$THEME_NAME"
DEFAULTS=/etc/default/grub
STAMP="$(date +%Y%m%d-%H%M%S)"

[ "$OS_FAMILY" = arch ] || warn "written against Arch's GRUB layout; paths may differ on $OS_ID"
have grub-mkconfig || die "grub-mkconfig not found — is GRUB actually installed?"
[ -d "$SRC" ] || die "missing $SRC (run system/grub/gen-assets.py first)"

need_sudo

# ------------------------------------------------------------------ uninstall
if [ "$UNINSTALL" = 1 ]; then
  run $SUDO rm -rf "$DEST"
  run $SUDO sed -i 's|^GRUB_THEME=.*|#GRUB_THEME=|' "$DEFAULTS"
  ok "removed $DEST and cleared GRUB_THEME"
  [ "$REGEN" = 1 ] && run $SUDO grub-mkconfig -o /boot/grub/grub.cfg
  exit 0
fi

# --------------------------------------------------------------------- fonts
# grub-mkfont derives the in-theme font name as "<-n value> <style> <size>",
# so the names below must stay in sync with the font = "..." lines in theme.txt.
FONT_REG=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf
FONT_BOLD=/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf
if [ ! -r "$FONT_REG" ] || [ ! -r "$FONT_BOLD" ]; then
  warn "JetBrains Mono Nerd Font not found, falling back to DejaVu Sans Mono"
  FONT_REG=/usr/share/fonts/TTF/DejaVuSansMono.ttf
  FONT_BOLD=/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf
fi
[ -r "$FONT_REG" ] || die "no usable TTF found to build GRUB fonts from"

mkfont() { # <ttf> <family> <size> <outfile>
  log "font: $2 @ $3"
  # grub-mkfont is noisy about OpenType features GRUB cannot use.
  run grub-mkfont -s "$3" -n "$2" -o "$4" "$1" 2> >(grep -v 'unsupported font feature' >&2 || true)
}

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -r "$SRC"/. "$STAGE/"

mkfont "$FONT_REG"  "Tokyo Night Mono" 16 "$STAGE/mono-16.pf2"
mkfont "$FONT_REG"  "Tokyo Night Mono" 20 "$STAGE/mono-20.pf2"
mkfont "$FONT_BOLD" "Tokyo Night Mono" 20 "$STAGE/mono-bold-20.pf2"
mkfont "$FONT_BOLD" "Tokyo Night"      32 "$STAGE/title-32.pf2"

# ------------------------------------------------------------------- install
log "installing theme -> $DEST"
run $SUDO rm -rf "$DEST"
run $SUDO mkdir -p "$DEST"
run $SUDO cp -r "$STAGE"/. "$DEST/"
run $SUDO chmod -R a+rX "$DEST"

# -------------------------------------------------------- /etc/default/grub
# set_key <key> <value> — replace the line whether it is set or commented out,
# appending it if the key is absent entirely.
set_key() {
  local key="$1" val="$2"
  # No sudo on the probe: /etc/default/grub is world-readable, and a sudo
  # prompt failing here would silently send us down the append branch and
  # duplicate the key instead of replacing it.
  if grep -qE "^#?[[:space:]]*$key=" "$DEFAULTS"; then
    run $SUDO sed -i -E "s|^#?[[:space:]]*$key=.*|$key=$val|" "$DEFAULTS"
  elif [ "${DRY_RUN:-0}" = 1 ]; then
    printf '%s   $%s append %s=%s to %s\n' "$C_DIM" "$C_RESET" "$key" "$val" "$DEFAULTS"
  else
    printf '%s=%s\n' "$key" "$val" | $SUDO tee -a "$DEFAULTS" >/dev/null
  fi
}

run $SUDO cp -a "$DEFAULTS" "$DEFAULTS.bak-$STAMP"
set_key GRUB_THEME "\"$DEST/theme.txt\""
# The background is authored at 1080p; ask for it and let GRUB fall back.
set_key GRUB_GFXMODE "1920x1080x32,1920x1080,auto"
set_key GRUB_GFXPAYLOAD_LINUX keep
# A graphical theme needs the gfxterm output; console would silently ignore it.
run $SUDO sed -i -E 's|^GRUB_TERMINAL_OUTPUT=console|#GRUB_TERMINAL_OUTPUT=console|' "$DEFAULTS"
ok "updated $DEFAULTS (backup: $DEFAULTS.bak-$STAMP)"

# -------------------------------------------------------------------- regen
if [ "$REGEN" = 1 ]; then
  [ -f /boot/grub/grub.cfg ] && run $SUDO cp -a /boot/grub/grub.cfg "/boot/grub/grub.cfg.bak-$STAMP"
  log "regenerating /boot/grub/grub.cfg"
  run $SUDO grub-mkconfig -o /boot/grub/grub.cfg
  ok "grub.cfg regenerated (backup: /boot/grub/grub.cfg.bak-$STAMP)"
else
  warn "skipped grub-mkconfig — run it yourself to apply"
fi

ok "Tokyo Night GRUB theme installed"
