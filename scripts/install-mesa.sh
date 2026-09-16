#!/usr/bin/env bash
# Unpack .tmp archives and compile MESA as the non-root mesa user.
set -euo pipefail

MESA_USER="${MESA_USER:-mesa}"
MESA_DIR="${MESA_DIR:-/opt/mesa}"
MESASDK_ROOT="${MESASDK_ROOT:-/opt/mesasdk}"
ARCHIVE_DIR="${ARCHIVE_DIR:-/archives}"
MESA_ARCHIVE="${MESA_ARCHIVE:-mesa-26.04.1.zip}"
MESASDK_ARCHIVE="${MESASDK_ARCHIVE:-mesasdk-x86_64-linux-26.6.1.tar.gz}"

mesa_zip="${ARCHIVE_DIR}/${MESA_ARCHIVE}"
sdk_tar="${ARCHIVE_DIR}/${MESASDK_ARCHIVE}"

if [ ! -f "${mesa_zip}" ]; then
  echo "error: missing ${mesa_zip}" >&2
  echo "Put ${MESA_ARCHIVE} in .tmp/ or run scripts/fetch-archives.sh" >&2
  exit 1
fi
if [ ! -f "${sdk_tar}" ]; then
  echo "error: missing ${sdk_tar}" >&2
  echo "Put ${MESASDK_ARCHIVE} in .tmp/ or run scripts/fetch-archives.sh" >&2
  exit 1
fi

echo "unpacking MESA SDK from ${sdk_tar}"
mkdir -p /opt
tar -xzf "${sdk_tar}" -C /opt
sdk_unpacked="$(find /opt -mindepth 1 -maxdepth 1 -type d -name 'mesasdk*' | head -n 1)"
if [ -z "${sdk_unpacked}" ]; then
  echo "error: SDK tarball did not contain a mesasdk directory" >&2
  exit 1
fi
if [ "${sdk_unpacked}" != "${MESASDK_ROOT}" ]; then
  rm -rf "${MESASDK_ROOT}"
  mv "${sdk_unpacked}" "${MESASDK_ROOT}"
fi

echo "unpacking MESA from ${mesa_zip}"
unzip -q "${mesa_zip}" -d /opt
mesa_unpacked="$(find /opt -mindepth 1 -maxdepth 1 -type d -name 'mesa-*' | head -n 1)"
if [ -z "${mesa_unpacked}" ]; then
  echo "error: MESA zip did not contain a mesa directory" >&2
  exit 1
fi
if [ "${mesa_unpacked}" != "${MESA_DIR}" ]; then
  rm -rf "${MESA_DIR}"
  mv "${mesa_unpacked}" "${MESA_DIR}"
fi

chown -R "${MESA_USER}:${MESA_USER}" "${MESA_DIR}" "${MESASDK_ROOT}"

nprocs="$(nproc)"
echo "compiling MESA as ${MESA_USER} with NPROCS=${nprocs}"
runuser -u "${MESA_USER}" -- bash -eo pipefail <<EOF
export MESA_DIR='${MESA_DIR}'
export MESASDK_ROOT='${MESASDK_ROOT}'
export HOME='$(getent passwd "${MESA_USER}" | cut -d: -f6)'
export OMP_NUM_THREADS='${nprocs}'
export NPROCS='${nprocs}'
export HDF5_USE_FILE_LOCKING=FALSE
# shellcheck disable=SC1091
source "\${MESASDK_ROOT}/bin/mesasdk_init.sh"
gfortran --version
cd "\${MESA_DIR}"
./install
EOF

echo "MESA installation finished"
