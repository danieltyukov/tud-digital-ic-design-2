#!/bin/bash
# Launch Cadence Virtuoso on the ET4382 remote desktop (RDP / xrdp).
#
# Switched away from ee4615 (ssh -X) because that box is overloaded and slow.
# ET4382 only exposes RDP (port 3389, ssh/22 is firewalled), so this connects
# to a full xrdp desktop instead of forwarding a single X11 window.
#
# Fallback to the old (slow) ee4615 ssh path: ./launch-cadence-ee4615.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_ET4382.txt"

NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')
SERVER=$(grep '^server:'   "${CRED_FILE}" | awk '{print $2}')

if ! command -v xfreerdp3 >/dev/null && ! command -v xfreerdp >/dev/null; then
    notify-send "Cadence ET4382" "xfreerdp is not installed. Run: sudo apt install freerdp3-x11" 2>/dev/null || true
    echo "ERROR: xfreerdp not found. Install with: sudo apt install freerdp3-x11" >&2
    exit 1
fi

RDP=$(command -v xfreerdp3 || command -v xfreerdp)

# Fixed 1920x1080 framebuffer (xrdp-friendly); /smart-sizing lets the local
# window manager resize/snap the window freely while the framebuffer scales.
exec "$RDP" \
    /v:"$SERVER" \
    /u:"$NETID" \
    /p:"$PASSWORD" \
    /cert:ignore \
    /sec:rdp \
    /bpp:16 \
    +clipboard \
    /size:1920x1080 \
    /smart-sizing \
    -wallpaper \
    -themes \
    -menu-anims \
    -window-drag \
    /title:"Cadence ET4382 (${SERVER})"
