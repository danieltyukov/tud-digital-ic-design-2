#!/bin/bash
# One-shot bootstrap for the EE4615 Cadence account on ee4615.ewi.tudelft.nl.
#
# What this does (idempotent):
#   1. Ensures ~/tsmcBCD/ exists (NFS-shared with other TUD courses, may already exist).
#   2. Copies the EE4615-specific sourceme.ee4615 from the system PDK dir.
#      (We don't run the system "start" script — that would overwrite the
#       existing cds.lib with all the EE4610 / SMPC / et4382 libraries.)
#   3. Creates working dirs the TDC testbench OCEAN scripts expect:
#      ~/simulation/, ~/tmp/, ~/sims/
#   4. Uploads the Testbench library + .ocn scripts to ~/tsmcBCD/Testbench/.
#   5. Registers Testbench in ~/tsmcBCD/cds.lib (appends DEFINE only if absent).
#
# After this finishes, use launch-cadence.sh for every routine session.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_username.txt"

SERVER="ee4615.ewi.tudelft.nl"
NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')

TESTBENCH_SRC="${SCRIPT_DIR}/Testbench_180nm_tech_2026/Testbench_180nm_tech"

if [[ ! -d "${TESTBENCH_SRC}/Testbench" ]]; then
    echo "ERROR: Testbench source not found at ${TESTBENCH_SRC}/Testbench" >&2
    exit 1
fi

echo "[1/4] Ensuring ~/tsmcBCD/ and sourceme.ee4615 on ${NETID}@${SERVER} ..."
# Login shell on ee4615 is tcsh; feed the script as stdin so quoting stays sane.
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=accept-new \
    "${NETID}@${SERVER}" <<'REMOTE'
set SYS_PDK = /opt/ei/DK/tsmc/oa180/mini018BCDG2/216A/et4382
if ( ! -d $HOME/tsmcBCD ) mkdir $HOME/tsmcBCD
if ( ! -f $HOME/tsmcBCD/sourceme.ee4615 ) then
    cp $SYS_PDK/sourceme.ee4615 $HOME/tsmcBCD/
    echo "  copied sourceme.ee4615"
else
    echo "  sourceme.ee4615 already present"
endif
foreach d ( $HOME/simulation $HOME/tmp $HOME/sims )
    if ( ! -d $d ) mkdir $d
end
echo "  working dirs ready: simulation/ tmp/ sims/"
REMOTE

echo "[2/4] Uploading Testbench/ + OCEAN scripts to ~/tsmcBCD/ ..."
sshpass -p "${PASSWORD}" scp -r -q \
    "${TESTBENCH_SRC}/Testbench" \
    "${TESTBENCH_SRC}/testbench_tdc_binary.ocn" \
    "${TESTBENCH_SRC}/testbench_tdc_therm.ocn" \
    "${NETID}@${SERVER}:tsmcBCD/"
echo "  upload complete"

echo "[3/4] Registering Testbench library in ~/tsmcBCD/cds.lib ..."
# Remote shell is tcsh — pipe a bash payload through `bash -s` so we get
# regular shell expansion.
sshpass -p "${PASSWORD}" ssh "${NETID}@${SERVER}" bash -s <<'REMOTE'
set -e
CDS="$HOME/tsmcBCD/cds.lib"
if grep -Eq "^DEFINE[[:space:]]+Testbench[[:space:]]+" "$CDS"; then
    echo "  Testbench already registered"
else
    echo "DEFINE Testbench ./Testbench" >> "$CDS"
    echo "  added: DEFINE Testbench ./Testbench"
fi
REMOTE

echo "[4/4] All done. Run ./launch-cadence.sh for normal sessions."
