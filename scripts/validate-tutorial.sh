#!/usr/bin/env bash
# Compile and run the official MESA star/work tutorial through ZAMS.
set -euo pipefail

if [ -f /etc/profile.d/mesa.sh ]; then
  # shellcheck disable=SC1091
  . /etc/profile.d/mesa.sh
fi

if [ -z "${MESA_DIR:-}" ] || [ ! -d "${MESA_DIR}" ]; then
  echo "error: MESA_DIR is not set or ${MESA_DIR:-unset} does not exist" >&2
  echo "Build the full image (docker compose build) rather than the base target." >&2
  exit 1
fi

if [ ! -f "${MESASDK_ROOT:-}/bin/mesasdk_init.sh" ]; then
  echo "error: MESA SDK is not initialized at ${MESASDK_ROOT:-unset}" >&2
  exit 1
fi

if [ ! -d "${MESA_DIR}/star/work" ]; then
  echo "error: ${MESA_DIR}/star/work is missing; MESA install looks incomplete" >&2
  exit 1
fi

WORK="${MESA_TUTORIAL_DIR:-${HOME}/work/tutorial}"
mkdir -p "$(dirname "${WORK}")"
rm -rf "${WORK}"
cp -a "${MESA_DIR}/star/work" "${WORK}"
cd "${WORK}"

if [ "${PGSTAR:-0}" != "1" ]; then
  python3 - <<'PY'
from pathlib import Path

path = Path("inlist_project")
text = path.read_text()
updated = text.replace("pgstar_flag = .true.", "pgstar_flag = .false.")
if updated == text:
    raise SystemExit("could not disable pgstar_flag in inlist_project")
path.write_text(updated)
print("pgstar disabled for headless tutorial run")
PY
fi

echo "compiling tutorial in ${WORK}"
./mk
if [ ! -x ./star ]; then
  echo "error: ./mk did not produce an executable ./star" >&2
  exit 1
fi

echo "running tutorial (./rn)"
./rn | tee rn.log

if ! grep -q "Lnuc_div_L_zams_limit" rn.log; then
  echo "error: tutorial did not stop at the ZAMS Lnuc/L limit" >&2
  tail -n 50 rn.log >&2
  exit 1
fi

if [ ! -s LOGS/history.data ]; then
  echo "error: LOGS/history.data was not written" >&2
  exit 1
fi

echo "tutorial validation succeeded"
echo "work directory: ${WORK}"
