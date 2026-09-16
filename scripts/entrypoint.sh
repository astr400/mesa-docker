#!/usr/bin/env bash
set -euo pipefail

MESA_USER="${MESA_USER:-mesa}"
MESA_HOME="$(getent passwd "${MESA_USER}" | cut -d: -f6)"
DISPLAY_NUM="${DISPLAY_NUM:-1}"
VNC_PORT="${VNC_PORT:-5901}"
NOVNC_PORT="${NOVNC_PORT:-6080}"
SCREEN_GEOM="${SCREEN_GEOM:-1920x1080x24}"

install -d -m 0755 /run/sshd /var/run/sshd /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
  ssh-keygen -A
fi

install -d -m 0755 -o "${MESA_USER}" -g "${MESA_USER}" \
  "${MESA_HOME}" "${MESA_HOME}/work"
install -d -m 0700 -o "${MESA_USER}" -g "${MESA_USER}" "${MESA_HOME}/.ssh"

auth_keys="${MESA_HOME}/.ssh/authorized_keys"
umask 077
: >"${auth_keys}"

if [ -n "${AUTHORIZED_KEYS:-}" ]; then
  printf '%s\n' "${AUTHORIZED_KEYS}" >>"${auth_keys}"
fi

if [ -f /tmp/host_authorized_keys ] && [ -s /tmp/host_authorized_keys ]; then
  cat /tmp/host_authorized_keys >>"${auth_keys}"
fi

chown "${MESA_USER}:${MESA_USER}" "${auth_keys}"
chmod 600 "${auth_keys}"

if [ ! -s "${auth_keys}" ]; then
  echo "warning: no SSH authorized keys provided; set AUTHORIZED_KEYS or mount a key file at /tmp/host_authorized_keys" >&2
fi

if [ ! -e /usr/share/novnc/index.html ] && [ -e /usr/share/novnc/vnc.html ]; then
  ln -sf vnc.html /usr/share/novnc/index.html
fi

export DISPLAY=":${DISPLAY_NUM}"

echo "starting Xvfb on ${DISPLAY} (${SCREEN_GEOM})"
runuser -u "${MESA_USER}" -- env DISPLAY="${DISPLAY}" \
  Xvfb "${DISPLAY}" -screen 0 "${SCREEN_GEOM}" -ac +extension GLX +render -noreset &

for _ in $(seq 1 50); do
  if [ -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ]; then
    break
  fi
  sleep 0.1
done

if [ ! -S "/tmp/.X11-unix/X${DISPLAY_NUM}" ]; then
  echo "error: Xvfb did not create /tmp/.X11-unix/X${DISPLAY_NUM}" >&2
  exit 1
fi

echo "starting fluxbox"
runuser -u "${MESA_USER}" -- env DISPLAY="${DISPLAY}" fluxbox >/tmp/fluxbox.log 2>&1 &

echo "starting x11vnc on :${VNC_PORT}"
runuser -u "${MESA_USER}" -- env DISPLAY="${DISPLAY}" \
  x11vnc -display "${DISPLAY}" -forever -shared -nopw -listen 0.0.0.0 \
  -rfbport "${VNC_PORT}" -xkb -ncache 0 -noxdamage >/tmp/x11vnc.log 2>&1 &

NOVNC_WEB="${NOVNC_WEB:-/usr/share/novnc}"
echo "starting noVNC on :${NOVNC_PORT} (${NOVNC_WEB})"
websockify --web="${NOVNC_WEB}" "${NOVNC_PORT}" "127.0.0.1:${VNC_PORT}" >/tmp/novnc.log 2>&1 &

if [ "$#" -gt 0 ]; then
  echo "running command as ${MESA_USER}: $*"
  exec runuser -u "${MESA_USER}" -- "$@"
fi

echo "starting sshd on :22"
exec /usr/sbin/sshd -D -e
