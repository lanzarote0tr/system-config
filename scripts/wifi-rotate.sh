#!/usr/bin/env bash
# Cycle through a fixed list of Wi-Fi networks until one of them actually
# hands out an IP lease.
#
# Associating is not the same as being on the network: an AP will happily let
# you associate and then never answer DHCP. So every attempt is judged on one
# thing only — did we get a real IPv4 address within LEASE_TIMEOUT seconds?
# If not, the connection is torn down and the next SSID gets its turn. The
# rotation repeats forever, so leaving this running means you land on whichever
# network comes back first.
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/common.sh"

# --------------------------------------------------------------- defaults
# Override any of these from the environment, or pass SSIDs as arguments.
SSIDS=("G06-109" "G06-109_IoT" "G109_IoT_2.4G" "Ethan")
LEASE_TIMEOUT="${LEASE_TIMEOUT:-12}"   # seconds to wait for a DHCP lease
ROUND_PAUSE="${ROUND_PAUSE:-5}"        # seconds to rest between full rounds
HOLD="${HOLD:-1}"                      # 1 = stay and watch once connected
ROUNDS="${ROUNDS:-0}"                  # 0 = forever
IFACE="${IFACE:-}"

usage() {
  cat <<EOF
usage: ${0##*/} [options] [SSID ...]

Rotate through the given SSIDs (default: ${SSIDS[*]}) until one of them
issues a DHCP lease within ${LEASE_TIMEOUT}s.

options:
  -t, --timeout SEC   seconds to wait for a lease per attempt (default $LEASE_TIMEOUT)
  -p, --pause SEC     seconds between full rounds (default $ROUND_PAUSE)
  -i, --iface DEV     wireless interface (default: first wifi device)
  -r, --rounds N      give up after N rounds (default: never give up)
  -1, --once          same as --rounds 1
  -n, --no-hold       exit as soon as a lease is obtained
  -h, --help          this text
EOF
}

# ------------------------------------------------------------ arg parsing
ssid_args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -t|--timeout) LEASE_TIMEOUT="$2"; shift 2 ;;
    -p|--pause)   ROUND_PAUSE="$2";   shift 2 ;;
    -i|--iface)   IFACE="$2";         shift 2 ;;
    -r|--rounds)  ROUNDS="$2";        shift 2 ;;
    -1|--once)    ROUNDS=1;           shift ;;
    -n|--no-hold) HOLD=0;             shift ;;
    -h|--help)    usage; exit 0 ;;
    -*)           usage >&2; die "unknown option: $1" ;;
    *)            ssid_args+=("$1"); shift ;;
  esac
done
[ ${#ssid_args[@]} -gt 0 ] && SSIDS=("${ssid_args[@]}")

command -v nmcli >/dev/null || die "nmcli not found; this script drives NetworkManager"

if [ -z "$IFACE" ]; then
  IFACE="$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')"
  [ -n "$IFACE" ] || die "no wifi interface found (pass --iface)"
fi

# --------------------------------------------------------------- helpers

# Print the interface's IPv4 address, ignoring the 169.254/16 self-assigned
# range that means "DHCP never answered".
current_ip() {
  nmcli -g IP4.ADDRESS device show "$IFACE" 2>/dev/null |
    head -n1 | cut -d/ -f1 | grep -v '^169\.254\.' || true
}

# Wait up to LEASE_TIMEOUT for a lease. Returns the address on success.
wait_for_lease() {
  local deadline=$((SECONDS + LEASE_TIMEOUT)) ip
  while [ "$SECONDS" -lt "$deadline" ]; do
    ip="$(current_ip)"
    if [ -n "$ip" ]; then
      printf '%s\n' "$ip"
      return 0
    fi
    sleep 1
  done
  return 1
}

# Bring the SSID up. Prefer the saved profile; fall back to a fresh scan-and-
# connect for one we have never joined. nmcli's own --wait bounds the attempt
# so a silent AP cannot stall the rotation.
connect() {
  local ssid="$1"
  if nmcli -t -g NAME connection show | grep -qxF "$ssid"; then
    nmcli --wait "$LEASE_TIMEOUT" connection up id "$ssid" ifname "$IFACE" >/dev/null 2>&1
  else
    nmcli --wait "$LEASE_TIMEOUT" device wifi connect "$ssid" ifname "$IFACE" >/dev/null 2>&1
  fi
}

disconnect() {
  nmcli --wait 5 device disconnect "$IFACE" >/dev/null 2>&1 || true
}

# Sit on a working connection and return once it stops having an address, so
# the caller can resume rotating.
hold_connection() {
  local ssid="$1"
  log "holding $ssid — ctrl-c to stop"
  while [ -n "$(current_ip)" ]; do
    sleep 5
  done
  warn "$ssid dropped its lease; resuming rotation"
}

cleanup() { printf '\n'; log "stopped"; exit 130; }
trap cleanup INT TERM

# ------------------------------------------------------------------ main
log "rotating over ${#SSIDS[@]} networks on $IFACE (${LEASE_TIMEOUT}s lease window)"

round=0
while :; do
  round=$((round + 1))
  for ssid in "${SSIDS[@]}"; do
    printf '%s==>%s [round %d] trying %s\n' "$C_BLUE" "$C_RESET" "$round" "$ssid"
    disconnect

    if ! connect "$ssid"; then
      skip "$ssid did not associate"
      continue
    fi

    if ip="$(wait_for_lease)"; then
      ok "$ssid is up with $ip"
      [ "$HOLD" = 1 ] || exit 0
      hold_connection "$ssid"
      round=0
      continue
    fi

    skip "$ssid associated but gave no lease in ${LEASE_TIMEOUT}s"
    disconnect
  done

  if [ "$ROUNDS" -gt 0 ] && [ "$round" -ge "$ROUNDS" ]; then
    die "no network handed out a lease after $round round(s)"
  fi
  sleep "$ROUND_PAUSE"
done
