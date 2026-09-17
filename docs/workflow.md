# MESA workflow with this container

The image holds a compiled MESA at `$MESA_DIR` (`/opt/mesa`). Science lives on **host bind mounts**, not in the image and not in a Docker named volume. Official references: [Running MESA](https://docs.mesastar.org/en/latest/using_mesa/running.html), [Building inlists](https://docs.mesastar.org/en/latest/using_mesa/building_inlists.html), [Best practices](https://docs.mesastar.org/en/latest/using_mesa/best_practices.html).

## Layout

| Location | Role |
| --- | --- |
| `/opt/mesa`, `/opt/mesasdk` | Immutable install in the image |
| `./work` → `/home/mesa/work` | Active projects. Edit inlists here. `./rn` writes `LOGS/`, `photos/`, `png/`, `*.mod` here. |
| `./results` → `/home/mesa/results` | Frozen snapshots from `scripts/mesa archive` |
| Port 2222 | SSH / Remote-SSH |
| Port 6080 | noVNC (pgstar) |
| Port 5901 | VNC client |

Deleting or recreating the container does **not** delete `work/` or `results/`. Files created by MESA are owned by uid/gid **1000** (`mesa`).

[`scripts/mesa`](../scripts/mesa) only maps a host cwd under `./work`. `cd ~/papers/run-3 && ./scripts/mesa ./rn` fails. `seed` may be run from anywhere in the repo.

## Start the stack

```bash
export AUTHORIZED_KEYS="$(cat ~/.ssh/id_ed25519.pub)"
docker compose up -d
```

Build once with `--build` if the image is not present. Optional: put `scripts/` on `PATH` or `alias mesa=/path/to/mesa-docker/scripts/mesa`.

## New project

Keep projects **out of** `$MESA_DIR`. Each project is a copy of `$MESA_DIR/star/work` (or a `star/test_suite` case when the physics is closer).

```bash
./scripts/mesa seed tutorial
cd work/tutorial
```

`inlist` points at `inlist_project` and `inlist_pgstar`. Only set controls you mean to change. When you want a portable model at the end of a run, set `save_model_when_terminate = .true.` in `&star_job`.

## Edit locally, run in the container

Edit `inlist_project` (and extras under `src/`) in the host editor. From the project directory:

```bash
../../scripts/mesa ./mk
../../scripts/mesa ./rn
# after inlist changes, resume from a photo named in the run log
../../scripts/mesa ./re x207
```

`./rn` with no prior `./mk` will compile. An interactive shell at the same cwd: `../../scripts/mesa`.

## Outputs

| Path | Keep as | Notes |
| --- | --- | --- |
| `LOGS/history.data`, `LOGS/profile*.data` | Science product | On the host under `work/<project>/LOGS/` as soon as MESA writes them |
| `*.mod` | Portable model | Same MESA version preferred; not bitwise identical to a photo restart |
| `photos/` | Restart only | Binary; obsolete after a MESA upgrade. Use `./re` on **this** image |
| `png/`, `pgstar_out/` | Plots | Optional |

## Save off

The live `LOGS/` directory is already on the host. For a frozen copy you can keep evolving against:

```bash
cd work/tutorial
../../scripts/mesa archive
```

That writes `results/tutorial/<UTC-timestamp>/` with inlists, `src/`, `LOGS/`, `*.mod` if present, plots if present, and `provenance.txt` (MESA/SDK paths, image tag, threads, UTC). **`photos/` are not copied.**

Copy `results/...` to lab storage or upload to the [MESA Zenodo community](https://zenodo.org/communities/mesa/curation-policy) for a paper (inlists, `run_star_extras.f90`, MESA version, SDK version, OS/image).

Optional destination, still under `results/`:

```bash
../../scripts/mesa archive /path/to/mesa-docker/results/my-paper-run
```

## Git

Track inputs under `work/<project>`: `inlist*`, `src/`, column list files, `mk`/`rn`/`re`. Generated `LOGS/`, `photos/`, `png/`, `star`, and `*.mod` are gitignored. All of `results/` is gitignored (too large).

## pgstar

Set `pgstar_flag = .true.` and open `http://localhost:6080` (container `DISPLAY=:1`). Or `ssh -Y -p 2222 mesa@localhost`. Headless: `pgstar_flag = .false.`.

## What not to do

- Do not use [`scripts/validate-tutorial.sh`](../scripts/validate-tutorial.sh) as the science path. It **deletes and recopies** its work directory every time.
- Do not treat `photos/` as the archival product. Save `.mod` and `LOGS/`.
- Do not expect a GitHub interactive session (`tmate` / upterm) to keep `~/work`. That job has no durable volume.
- Do not edit or run science inside `/opt/mesa`.
