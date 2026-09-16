# shellcheck shell=bash
# MESA / MESA SDK environment for login and non-interactive shells.

export MESA_DIR="${MESA_DIR:-/opt/mesa}"
export MESASDK_ROOT="${MESASDK_ROOT:-/opt/mesasdk}"
export HDF5_USE_FILE_LOCKING="${HDF5_USE_FILE_LOCKING:-FALSE}"
# mesasdk_init.sh does MANPATH="${...}:${MANPATH}" and fails under `set -u`
# when MANPATH is unset (GitHub-hosted runners).
export MANPATH="${MANPATH:-}"

if [ -z "${OMP_NUM_THREADS:-}" ]; then
  if command -v nproc >/dev/null 2>&1; then
    OMP_NUM_THREADS="$(nproc)"
  else
    OMP_NUM_THREADS=2
  fi
  export OMP_NUM_THREADS
fi

if [ -f "${MESASDK_ROOT}/bin/mesasdk_init.sh" ]; then
  # shellcheck disable=SC1091
  . "${MESASDK_ROOT}/bin/mesasdk_init.sh"
fi

if [ -d "${MESA_DIR}/scripts/shmesa" ]; then
  case ":${PATH}:" in
    *":${MESA_DIR}/scripts/shmesa:"*) ;;
    *) PATH="${PATH}:${MESA_DIR}/scripts/shmesa" ;;
  esac
  export PATH
fi

# Default to the container framebuffer so pgstar shows up in noVNC.
# SSH X11 forwarding sets DISPLAY itself and should not be overridden.
if [ -z "${DISPLAY:-}" ]; then
  export DISPLAY=:1
fi
