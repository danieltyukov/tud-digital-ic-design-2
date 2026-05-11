#!/bin/bash
# Run one of the TDC testbench OCEAN scripts on the EE4615 server.
#
# Usage:
#   ./run-testbench.sh binary       # → testbench_tdc_binary.ocn
#   ./run-testbench.sh thermometer  # → testbench_tdc_therm.ocn
#
# After the OCEAN run, the result files are pulled back into ./results/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRED_FILE="${SCRIPT_DIR}/password_username.txt"
RESULTS_DIR="${SCRIPT_DIR}/results"

SERVER="ee4615.ewi.tudelft.nl"
NETID=$(grep '^login:'    "${CRED_FILE}" | awk '{print $2}')
PASSWORD=$(grep '^password:' "${CRED_FILE}" | awk '{print $2}')

case "${1:-binary}" in
    binary)        OCN="testbench_tdc_binary.ocn"; OUT_CSV="results_tdc_binary.csv"; OUT_LOG="log_tdc_binary.txt" ;;
    thermometer|therm) OCN="testbench_tdc_therm.ocn"; OUT_CSV="results_tdc_therm.csv"; OUT_LOG="log_tdc_therm.txt" ;;
    *) echo "Usage: $0 {binary|thermometer}" >&2; exit 1 ;;
esac

mkdir -p "${RESULTS_DIR}"

echo "[run-testbench] Loading ${OCN} on ${SERVER} ..."
sshpass -p "${PASSWORD}" ssh -o StrictHostKeyChecking=accept-new \
    "${NETID}@${SERVER}" "cd tsmcBCD && source sourceme.ee4615 && ocean -nograph -restore ${OCN}"

echo "[run-testbench] Fetching results -> ${RESULTS_DIR}/ ..."
sshpass -p "${PASSWORD}" scp \
    "${NETID}@${SERVER}:simulation/${OUT_CSV}" \
    "${NETID}@${SERVER}:simulation/${OUT_LOG}" \
    "${RESULTS_DIR}/"

echo "[run-testbench] Done."
echo "  ${RESULTS_DIR}/${OUT_CSV}"
echo "  ${RESULTS_DIR}/${OUT_LOG}"
