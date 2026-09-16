# MESA remote development container

x86_64 Docker environment for [MESA](https://docs.mesastar.org/) stellar evolution, with OpenSSH for Cursor / VS Code Remote-SSH and a noVNC fallback for pgstar.

Pinned versions:

- MESA **26.4.1** (`mesa-26.04.1.zip`)
- MESA SDK **26.6.1** (`mesasdk-x86_64-linux-26.6.1.tar.gz`)
- Ubuntu 24.04

## What you get

| Port | Service | Use |
| --- | --- | --- |
| 2222 | OpenSSH | Shell, Cursor / VS Code Remote-SSH, `ssh -Y` X11 forwarding |
| 5901 | VNC | Native VNC client to the pgstar framebuffer |
| 6080 | noVNC | Browser UI at `http://host:6080` |

Work directories live in the `mesa-work` volume at `/home/mesa/work`. MESA itself is compiled into the image at `/opt/mesa`.

SSH is key-only. There is no default password.

## Prerequisites

- Docker with Compose v2 and BuildKit
- ~20 GB free disk for the image, 8 GB+ RAM recommended
- An SSH public key
- Archives in [`.tmp/`](.tmp/README.md) (already present on this machine)

Do not compile MESA as root. The image builds it as user `mesa` (uid 1000).

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

The tutorial job is `workflow_dispatch` only and pulls a published GHCR image. It does not download the 2 GB MESA zip on every PR. Wire those URL paths when the image is published.

## Layout

- `Dockerfile` — `base` (SSH + VNC) and `mesa` (compiled MESA) stages
- `docker-compose.yml` — ports 2222 / 5901 / 6080 and the work volume
- `scripts/entrypoint.sh` — sshd, Xvfb, fluxbox, x11vnc, noVNC
- `scripts/install-mesa.sh` — unpack `.tmp` archives and `./install` as `mesa`
- `scripts/validate-tutorial.sh` — official `star/work` tutorial
- `scripts/fetch-archives.sh` — optional Zenodo download into `.tmp`
