#!/bin/bash
# activate.sh - turns on XeSS XMX (xess-xmx-linux) for Steam in
# things-steam-headless. Staged next to the package (~/.xess-xmx/.things/) by
# the xess-xmx service; run by Steam's unit before every Steam start
# (ExecStartPre in the steam-headless-steam.service drop-in that setup
# writes), as steamheadless.
#
# Upstream's install.sh is made for a desktop login: it puts the driver
# settings into ~/.config/environment.d, which only user-session processes
# see. In Steam Headless, Steam is a system unit, so this script runs
# install.sh and then hands the same settings to Steam through
# /run/xess-xmx/environment (EnvironmentFile= in the drop-in). Every game
# Steam starts inherits them.
#
# Nothing is written to the environment file, and Steam starts as before,
# when: the GPU has no XMX units (N100, Meteor Lake, ...), the package's
# driver does not load (upstream's session check), or ~/.xess-xmx/DISABLED
# exists. With DISABLED, install.sh's changes are also undone once
# (uninstall.sh).
set -u
PKG="$HOME/.xess-xmx"
OUT=/run/xess-xmx/environment
CONF="$HOME/.config/environment.d/50-xess-xmx.conf"
# install.sh drives its watcher and session check through the user manager
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

log() { echo "xess-xmx: $*"; }
rm -f "$OUT"

[ -f "$PKG/install.sh" ] || { log "no package in $PKG (xess-xmx service not run yet?)"; exit 0; }

if [ -e "$PKG/DISABLED" ]; then
  if [ -f "$PKG/run/session-driver" ]; then
    log "DISABLED: undoing install.sh"
    bash "$PKG/uninstall.sh" && rm -f "$PKG/run/session-driver"
  fi
  log "disabled ($PKG/DISABLED), Steam starts without it"
  exit 0
fi

# GPUs with XMX units, as upstream's README lists them: Xe3 (Panther Lake,
# Wildcat Lake), Xe2 (Battlemage, Lunar Lake), Xe-HPG (Alchemist, Arrow
# Lake-H)
gpu=""
for dev in /sys/bus/pci/devices/*; do
  [ "$(cat "$dev/vendor" 2>/dev/null)" = 0x8086 ] || continue
  case "$(cat "$dev/class" 2>/dev/null)" in 0x03*) ;; *) continue ;; esac
  id=$(cat "$dev/device" 2>/dev/null) || continue
  n=$((id))
  if (( (n >= 0xB080 && n <= 0xB0FF) || (n >= 0xFD80 && n <= 0xFD8F) ||
        (n >= 0xE200 && n <= 0xE2FF) || (n >= 0x6420 && n <= 0x64FF) ||
        (n >= 0x5690 && n <= 0x56FF) || n == 0x7D51 || n == 0x7DD1 )); then
    gpu=$id
  fi
done
[ -n "$gpu" ] || { log "no Intel GPU with XMX units, Steam starts without it"; exit 0; }

log "release $(cat "$PKG/.release" 2>/dev/null), GPU $gpu"
bash "$PKG/install.sh" || log "install.sh exited with $?"

if [ ! -f "$CONF" ]; then
  log "install.sh wrote no environment ($CONF), Steam starts without it"
  exit 0
fi
# The same check upstream runs before each desktop session: the package's
# driver loads and finds the GPU. If not, Steam keeps the stock driver.
if ! bash "$PKG/tools/session-check.sh" --dry-run; then
  log "the package's driver does not load ($(head -1 "$HOME/.cache/xess-xmx/driver-status" 2>/dev/null)), Steam starts without it"
  exit 0
fi
grep -v '^[[:space:]]*\(#\|$\)' "$CONF" > "$OUT.new" && mv -f "$OUT.new" "$OUT"
log "on: $(tr '\n' ' ' < "$OUT")"
