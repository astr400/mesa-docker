#!/usr/bin/env bash
# Start a tmate session with a hard ready-timeout. Exit 1 if tmate.io never
# becomes ready so the workflow can fall back to upterm.
set -euo pipefail

SOCK="${TMATE_SOCK:-/tmp/tmate.sock}"
ACTOR="${GITHUB_ACTOR:?GITHUB_ACTOR is required}"
READY_TIMEOUT="${TMATE_READY_TIMEOUT:-20}"
AUTH="${HOME}/.ssh/authorized_keys"

echo "==> fetching public SSH keys for ${ACTOR}"
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
curl -fsSL --max-time 20 "https://github.com/${ACTOR}.keys" -o "${AUTH}"
if [ ! -s "${AUTH}" ]; then
  echo "error: no public SSH keys on https://github.com/${ACTOR}.keys" >&2
  echo "Add a key at https://github.com/settings/keys and re-run." >&2
  exit 1
fi
chmod 600 "${AUTH}"
echo "loaded $(grep -c . "${AUTH}") key(s)"

if ! command -v tmate >/dev/null 2>&1; then
  echo "==> installing tmate"
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends tmate
fi
echo "tmate $(tmate -V 2>/dev/null || true)"

echo "==> starting tmate (ready timeout ${READY_TIMEOUT}s)"
rm -f "${SOCK}"
tmate -S "${SOCK}" -a "${AUTH}" new-session -d
if ! timeout "${READY_TIMEOUT}" tmate -S "${SOCK}" wait tmate-ready; then
  echo "::warning::tmate.io did not become ready in ${READY_TIMEOUT}s; giving up on tmate"
  tmate -S "${SOCK}" kill-session >/dev/null 2>&1 || true
  rm -f "${SOCK}"
  exit 1
fi

SSH="$(tmate -S "${SOCK}" display -p '#{tmate_ssh}')"
WEB="$(tmate -S "${SOCK}" display -p '#{tmate_web}' || true)"

print_conn() {
  echo "============================================================"
  echo "SSH: ${SSH}"
  if [ -n "${WEB}" ]; then
    echo "Web shell: ${WEB}"
  else
    echo "Web shell: (not provided by this tmate server; use SSH)"
  fi
  echo "Connect from a machine that has your GitHub SSH key."
  echo "Type exit in that shell to end the job."
  echo "============================================================"
}

print_conn
while [ -S "${SOCK}" ]; do
  sleep 5
  if [ ! -S "${SOCK}" ]; then
    break
  fi
  print_conn
done

echo "tmate session ended"
