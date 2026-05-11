#!/bin/bash
# Register a Cadence library (already copied into ~/tsmcBCD/ on EE4615
# server) by adding a DEFINE entry to ~/tsmcBCD/cds.lib. Idempotent.
#
# Usage: ./register-library.sh LIBNAME [LIBNAME ...]
# Example: ./register-library.sh tdc_2d_vernier

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_username.txt"

SERVER="ee4615.ewi.tudelft.nl"

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 LIBNAME [LIBNAME ...]" >&2
    echo "Example: $0 tdc_2d_vernier" >&2
    exit 1
fi

NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')

# Remote shell is tcsh — base64-encode a bash payload to side-step cross-shell quoting.
for LIB in "$@"; do
    echo "=== $LIB ==="
    PAYLOAD=$(cat <<EOF
set -e
LIB='$LIB'
CDS="\$HOME/tsmcBCD/cds.lib"
DIR="\$HOME/tsmcBCD/\$LIB"
if [ ! -d "\$DIR" ]; then
    echo "  MISSING: \$DIR does not exist on $SERVER"
    exit 2
fi
if [ ! -f "\$DIR/cdsinfo.tag" ]; then
    echo "  WARNING: \$DIR has no cdsinfo.tag — may not be a valid Cadence library"
fi
if grep -Eq "^DEFINE[[:space:]]+\$LIB[[:space:]]+" "\$CDS"; then
    echo "  already registered in cds.lib"
else
    echo "DEFINE \$LIB \$DIR" >> "\$CDS"
    echo "  added: DEFINE \$LIB \$DIR"
fi
EOF
)
    B64=$(printf '%s' "$PAYLOAD" | base64 -w0)
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=accept-new "$NETID@$SERVER" \
        "echo $B64 | base64 -d | bash" \
        || echo "  FAILED for $LIB"
done

echo
echo "Done. Refresh the Library Manager in Virtuoso (File -> Refresh) to see new libraries."
