#!/bin/bash
# Mount remote ~/tsmcBCD on ee4615.ewi.tudelft.nl into ./tsmcBCD/ via sshfs.
#
# Keeps a live two-way view: Cadence writes go to the remote server,
# and they show up immediately in this repo for inspection / commit.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_username.txt"

SERVER="ee4615.ewi.tudelft.nl"
LOCAL_DIR="${SCRIPT_DIR}/tsmcBCD"
REMOTE_DIR="tsmcBCD"

NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')

mkdir -p "${LOCAL_DIR}"

if mountpoint -q "${LOCAL_DIR}"; then
    echo "tsmcBCD is already mounted at ${LOCAL_DIR}"
    exit 0
fi

echo "Mounting ${NETID}@${SERVER}:${REMOTE_DIR} -> ${LOCAL_DIR} ..."
echo "${PASSWORD}" | sshfs "${NETID}@${SERVER}:${REMOTE_DIR}" "${LOCAL_DIR}" \
    -o password_stdin \
    -o reconnect \
    -o ServerAliveInterval=15 \
    -o ServerAliveCountMax=3 \
    -o follow_symlinks

echo "Mounted: ${LOCAL_DIR}"
