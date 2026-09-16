#!/usr/bin/env bash
# Download MESA and MESA SDK archives into .tmp if they are not already present.
# Local builds should use files already in .tmp. GitHub Actions fetch wiring comes later.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${MESA_TMP_DIR:-${ROOT}/.tmp}"
mkdir -p "${TMP_DIR}"

MESA_ARCHIVE="${MESA_ARCHIVE:-mesa-26.04.1.zip}"
MESASDK_ARCHIVE="${MESASDK_ARCHIVE:-mesasdk-x86_64-linux-26.6.1.tar.gz}"

# Verified 2026-09-16: both Zenodo objects return HTTP 200.
MESA_URL="${MESA_URL:-https://zenodo.org/records/19722306/files/mesa-26.04.1.zip?download=1}"
MESASDK_URL="${MESASDK_URL:-https://zenodo.org/records/20598423/files/mesasdk-x86_64-linux-26.6.1.tar.gz?download=1}"
# Alternate SDK host (301 -> https://www.astro.wisc.edu/...); wget needs --user-agent="".
MESASDK_TOWNSEND_URL="${MESASDK_TOWNSEND_URL:-https://www.astro.wisc.edu/~townsend/resource/download/mesasdk/mesasdk-x86_64-linux-26.6.1.tar.gz}"

MESA_MD5="${MESA_MD5:-994fd28f38da92efc80e38ca11d8317b}"
MESASDK_MD5="${MESASDK_MD5:-c5ef95aafe07848988959fd45cfe8baf}"

download() {
  local url="$1"
  local dest="$2"
  echo "downloading ${url} -> ${dest}"
  curl -L --fail --retry 3 --retry-delay 2 -o "${dest}.partial" "${url}"
  mv "${dest}.partial" "${dest}"
}

check_md5() {
  local file="$1"
  local expected="$2"
  if [ -z "${expected}" ]; then
    return 0
  fi
  local actual
  actual="$(md5sum "${file}" | awk '{print $1}')"
  if [ "${actual}" != "${expected}" ]; then
    echo "error: md5 mismatch for ${file}: got ${actual}, expected ${expected}" >&2
    return 1
  fi
  echo "md5 ok: $(basename "${file}")"
}

mesa_zip="${TMP_DIR}/${MESA_ARCHIVE}"
sdk_tar="${TMP_DIR}/${MESASDK_ARCHIVE}"

if [ -f "${mesa_zip}" ]; then
  echo "using existing ${mesa_zip}"
else
  download "${MESA_URL}" "${mesa_zip}"
fi
check_md5 "${mesa_zip}" "${MESA_MD5}"

if [ -f "${sdk_tar}" ]; then
  echo "using existing ${sdk_tar}"
else
  if ! download "${MESASDK_URL}" "${sdk_tar}"; then
    echo "zenodo SDK download failed; trying Townsend mirror" >&2
    curl -L --fail --retry 3 --retry-delay 2 -A '' -o "${sdk_tar}.partial" "${MESASDK_TOWNSEND_URL}"
    mv "${sdk_tar}.partial" "${sdk_tar}"
  fi
fi
check_md5 "${sdk_tar}" "${MESASDK_MD5}"

echo "archives ready in ${TMP_DIR}"
ls -lh "${mesa_zip}" "${sdk_tar}"
