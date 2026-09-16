# MESA remote development container

Linux x86_64 environment for [MESA](https://docs.mesastar.org/) stellar evolution. Two tested paths:

1. **Local Docker** on Intel/AMD Linux: OpenSSH for Cursor / VS Code Remote-SSH, plus noVNC for pgstar.
2. **GitHub interactive session**: compile MESA on a hosted `ubuntu-latest` runner and SSH in with tmate (or upterm). Use this when you do not have a Linux x86_64 Docker host.

Pinned versions:

- MESA **26.4.1** (`mesa-26.04.1.zip`)
- MESA SDK **26.6.1** (`mesasdk-x86_64-linux-26.6.1.tar.gz`)
- Ubuntu 24.04

Local Docker is **linux/amd64 only**. There is no macOS image and no Darwin MESA SDK in this repo.

## What you get

| Port | Service | Use |
| --- | --- | --- |
| 2222 | OpenSSH | Shell, Cursor / VS Code Remote-SSH, `ssh -Y` X11 forwarding |
| 5901 | VNC | Native VNC client to the pgstar framebuffer |
| 6080 | noVNC | Browser UI at `http://host:6080` |

Those ports are the local Docker image. Work directories live in the `mesa-work` volume at `/home/mesa/work`. MESA itself is compiled into the image at `/opt/mesa`.

SSH is key-only. There is no default password.

## Prerequisites

Local Docker:

- Linux on Intel/AMD (`x86_64`)
- Docker with Compose v2 and BuildKit
- ~20 GB free disk for the image, 8 GB+ RAM recommended
- An SSH public key
- Archives in [`.tmp/`](.tmp/README.md) (already present on this machine)

Do not compile MESA as root. The image builds it as user `mesa` (uid 1000).

Without a Linux x86_64 Docker host, skip the local build and use the [interactive session](#interactive-session-on-github-hosted-runners) instead.

## Place or fetch archives

Build context reads:

- `.tmp/mesa-26.04.1.zip`
- `.tmp/mesasdk-x86_64-linux-26.6.1.tar.gz`

To download them later (GitHub Actions should not do this on every PR):

```bash
./scripts/fetch-archives.sh
```

Checked 2026-09-16:

- [Zenodo MESA r26.04.1](https://zenodo.org/records/19722306) — HTTP 200
- [Zenodo MESA SDK 26.6.1](https://zenodo.org/records/20598423) — HTTP 200
- Townsend SDK URL redirects 301 to HTTPS and is a fallback in the fetch script

## Build and run

```bash
export AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
docker compose up --build -d
```

The first full build unpacks the SDK, compiles MESA, and takes a long time. To exercise SSH/VNC without compiling MESA:

```bash
docker build --target base -t mesa-docker:base .
docker run --rm -p 2222:22 -p 6080:6080 -e AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)" mesa-docker:base
```

## Remote development over SSH

```bash
ssh -p 2222 -Y mesa@localhost
```

Cursor / VS Code: Remote-SSH to `mesa@host:2222` using the same key. The `mesa` user has passwordless sudo so the editor can install `~/.cursor-server`.

If you connect from another machine, publish port 2222 on the Docker host and use that host's address.

## GUI (pgstar)

- **SSH X11:** `ssh -Y -p 2222 mesa@host` and run a work directory with `pgstar_flag = .true.`
- **Browser:** open `http://host:6080` (container `DISPLAY=:1` via Xvfb + x11vnc + noVNC)
- **VNC client:** `host:5901` (no VNC password; keep this on a trusted network)

Headless / CI runs can disable plotting with `PGSTAR=0` (the default for `validate-tutorial.sh`).

## Validate with the tutorial

After the full image is up:

```bash
docker compose exec mesa /usr/local/bin/validate-tutorial.sh
```

That copies `$MESA_DIR/star/work`, runs `./mk` and `./rn`, and checks for a ZAMS stop (`Lnuc_div_L_zams_limit`) plus `LOGS/history.data`.

To watch pgstar in the browser, run the same tutorial with plotting on:

```bash
docker compose exec -e PGSTAR=1 -u mesa mesa bash -lc /usr/local/bin/validate-tutorial.sh
```

## GitHub Actions

[`.github/workflows/validate.yml`](.github/workflows/validate.yml) runs on pull requests:

- `shellcheck` on scripts
- `docker compose config`
- `docker build --target base` (SSH/GUI image, no MESA compile)

The tutorial job is `workflow_dispatch` only and pulls a published GHCR image. It does not download the 2 GB MESA zip on every PR.

### Interactive session on GitHub-hosted runners

[`.github/workflows/interactive.yml`](.github/workflows/interactive.yml) is the remote MESA workflow: it compiles MESA **on the GitHub-hosted runner** (not in Docker) and opens an SSH shell. Anyone with a GitHub account and an SSH key can use it; you do not need local Docker.

1. Add an [SSH key to your GitHub account](https://github.com/settings/keys). The key must be on the account that clicks **Run workflow**.
2. Open **Actions → Interactive MESA session → Run workflow**.
3. Leave **Download and compile MESA** checked unless you only need a bare runner. Pick a timeout (max 6 hours).
4. Wait until MESA finishes compiling (several minutes), then watch **Start tmate session**.
5. Within about 20 seconds that step should print `SSH:`. Copy the command and connect from a machine that has the matching private key.
6. If tmate.io never becomes ready, the job continues to **Start upterm session** and prints something like `ssh <id>@uptermd.upterm.dev`. Use that command instead.

MESA lives at `$HOME/mesa` (`$MESA_DIR`). The SDK is `$HOME/mesasdk`. Work in `~/work`. This is not the Docker image, so there is no noVNC/pgstar GUI on the runner. Use `PGSTAR=0` (file output only).

Run the official `star/work` tutorial from the checked-out repo:

```bash
PGSTAR=0 ./scripts/validate-tutorial.sh
```

Or by hand:

```bash
cp -r "$MESA_DIR/star/work" ~/work/tutorial
cd ~/work/tutorial && ./mk && ./rn
```

**Stay connected.** Closing the SSH client ends an upterm session and the GitHub job. If you need to walk away, run `tmux` first (install with `sudo apt-get install -y tmux` if needed), then detach with **Ctrl-b** then **d**. Reconnect with the same SSH command while the job is still yellow. Type `exit` only when you want the job to finish.

Only the user who started the workflow can connect (`limit-access-to-actor`). One session per user; starting another cancels the previous one. The job also stops at the timeout you selected.

## Layout

- `Dockerfile` — `base` (SSH + VNC) and `mesa` (compiled MESA) stages
- `docker-compose.yml` — ports 2222 / 5901 / 6080 and the work volume
- `scripts/entrypoint.sh` — sshd, Xvfb, fluxbox, x11vnc, noVNC
- `scripts/install-mesa.sh` — unpack `.tmp` archives and `./install` as `mesa`
- `scripts/validate-tutorial.sh` — official `star/work` tutorial
- `scripts/fetch-archives.sh` — optional Zenodo download into `.tmp`
- `scripts/start-tmate.sh` — tmate session with a 20s ready timeout
