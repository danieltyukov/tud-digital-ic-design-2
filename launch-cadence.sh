#!/bin/bash
# Launch Cadence Virtuoso on the EE4615 remote server.
#
# Routine session (after first-time-setup.sh has been run once):
#   ssh -X into ee4615.ewi.tudelft.nl, cd tsmcBCD, source sourceme.ee4615,
#   then virtuoso &.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_username.txt"

SERVER="ee4615.ewi.tudelft.nl"
NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')

# Mount the remote ~/tsmcBCD locally so working files appear in this repo too.
"${SCRIPT_DIR}/mount-tsmcBCD.sh"

# X11-forwarded Virtuoso. LD_LIBRARY_PATH is cleared so local libs don't
# bleed into the remote tcsh environment.
sshpass -p "${PASSWORD}" ssh -X "${NETID}@${SERVER}" \
    "setenv LD_LIBRARY_PATH '' && cd tsmcBCD && source sourceme.ee4615 && virtuoso &"
