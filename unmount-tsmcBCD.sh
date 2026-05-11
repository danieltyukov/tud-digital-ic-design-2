#!/bin/bash
# Unmount the sshfs-backed local view of remote ~/tsmcBCD.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="${SCRIPT_DIR}/tsmcBCD"

if ! mountpoint -q "${LOCAL_DIR}"; then
    echo "tsmcBCD is not mounted"
    exit 0
fi

fusermount -u "${LOCAL_DIR}"
echo "Unmounted ${LOCAL_DIR}"
