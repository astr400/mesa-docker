#!/usr/bin/env bash
# Unpack MESA archives and compile as a non-root user.
# Docker image: MESA_DIR=/opt/mesa, ARCHIVE_DIR=/archives, MESA_USER=mesa
# GitHub runner: MESA_DIR=$HOME/mesa, ARCHIVE_DIR=.tmp, MESA_USER=$USER
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

sdk_parent="$(dirname "${MESASDK_ROOT}")"
mesa_parent="$(dirname "${MESA_DIR}")"
mkdir -p "${sdk_parent}" "${mesa_parent}"

echo "unpacking MESA SDK from ${sdk_tar}"
tar -xzf "${sdk_tar}" -C "${sdk_parent}"
sdk_unpacked="$(find "${sdk_parent}" -mindepth 1 -maxdepth 1 -type d -name 'mesasdk*' | head -n 1)"
if [ -z "${sdk_unpacked}" ]; then
  echo "error: SDK tarball did not contain a mesasdk directory" >&2
  exit 1
fi
if [ "${sdk_unpacked}" != "${MESASDK_ROOT}" ]; then
  rm -rf "${MESASDK_ROOT}"
  mv "${sdk_unpacked}" "${MESASDK_ROOT}"
fi

echo "unpacking MESA from ${mesa_zip}"
unzip -q "${mesa_zip}" -d "${mesa_parent}"
mesa_unpacked="$(find "${mesa_parent}" -mindepth 1 -maxdepth 1 -type d -name 'mesa-*' | head -n 1)"
if [ -z "${mesa_unpacked}" ]; then
  echo "error: MESA zip did not contain a mesa directory" >&2
  exit 1
fi
if [ "${mesa_unpacked}" != "${MESA_DIR}" ]; then
  rm -rf "${MESA_DIR}"
  mv "${mesa_unpacked}" "${MESA_DIR}"
fi

if [ "${DELETE_ARCHIVES:-false}" = "true" ]; then
  rm -f "${mesa_zip}" "${sdk_tar}" || true
fi

if [ "$(id -un)" != "${MESA_USER}" ]; then
  chown -R "${MESA_USER}:${MESA_USER}" "${MESA_DIR}" "${MESASDK_ROOT}"
fi

run_install() {
  export MESA_DIR
  export MESASDK_ROOT
  export OMP_NUM_THREADS="${OMP_NUM_THREADS:-$(nproc)}"
  export NPROCS="${NPROCS:-${OMP_NUM_THREADS}}"
  export HDF5_USE_FILE_LOCKING="${HDF5_USE_FILE_LOCKING:-FALSE}"
  # shellcheck disable=SC1091
  source "${MESASDK_ROOT}/bin/mesasdk_init.sh"
  gfortran --version
  cd "${MESA_DIR}"
  ./install
}

nprocs="$(nproc)"
echo "compiling MESA as ${MESA_USER} with NPROCS=${nprocs}"
if [ "$(id -un)" = "${MESA_USER}" ]; then
  run_install
else
  mesa_home="$(getent passwd "${MESA_USER}" | cut -d: -f6)"
  runuser -u "${MESA_USER}" -- env \
    MESA_DIR="${MESA_DIR}" \
    MESASDK_ROOT="${MESASDK_ROOT}" \
    HOME="${mesa_home}" \
    OMP_NUM_THREADS="${nprocs}" \
    NPROCS="${nprocs}" \
    HDF5_USE_FILE_LOCKING=FALSE \
    bash -eo pipefail <<'EOS'
# shellcheck disable=SC1091
source "${MESASDK_ROOT}/bin/mesasdk_init.sh"
gfortran --version
cd "${MESA_DIR}"
./install
EOS
fi

echo "MESA installation finished"
