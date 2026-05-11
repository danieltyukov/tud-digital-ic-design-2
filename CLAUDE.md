# CLAUDE.md — tud-digital-ic-design-2

Context for Claude Code when working in this repo. **The parent workspace
also has a `CLAUDE.md` (one level up); follow this file's overrides when
they differ.**

## What this repo is

A TU Delft EE4615 (Digital IC Design II) course project workspace.
We are building a **2-D Vernier Time-to-Digital Converter** in TSMC 180 nm
BCD, as **Group 22**, presenter / NetID `datyukov`. The Cadence schematic
work lives on the remote server `ee4615.ewi.tudelft.nl`; this repo holds
the scripts that drive that environment, the testbench source, and the
project documentation.

## Remote / credentials layout

- **Server:** `ee4615.ewi.tudelft.nl` (NFS-shared home dir with `ee4610`, `et4382`, etc. — same `/home/datyukov/` on all of them).
- **Credentials live in** `password_username.txt` (`login:` / `password:`). This file is gitignored — never commit it.
- Don't change the credential file format; every shell script in this repo parses it with `grep '^login:' | awk '{print $2}'`.

## Key directories

| Path                                  | What                                                        |
|---------------------------------------|-------------------------------------------------------------|
| `tutorials/`                          | Official EE4615 PDFs (manual, testbench instructions, corner analysis). Source of truth for the workflow. |
| `Testbench_180nm_tech_2026/`          | Unzipped Cadence Testbench library + OCEAN scripts (uploaded to remote by `first-time-setup.sh`). |
| `project/`                            | Hand-written project markdown (architecture, specs, testbench notes, plan, deliverables, refs). |
| `tsmcBCD/`                            | **sshfs mount point** — populated when `mount-tsmcBCD.sh` runs. Shows live remote `~/tsmcBCD/`. Gitignored. |
| `results/`                            | OCEAN result CSVs pulled back by `run-testbench.sh`. |
| `*.sh`                                | Setup / launch / mount / register / run-testbench scripts. |

## Scripts (each is the canonical way to do that thing — don't invent alternatives)

- `first-time-setup.sh` — idempotent bootstrap: ensures `~/tsmcBCD/` exists,
  copies `sourceme.ee4615` from the system PDK, makes working dirs
  (`~/simulation/`, `~/tmp/`, `~/sims/`), uploads the Testbench library, and
  appends `DEFINE Testbench ./Testbench` to `cds.lib` (only if absent).
- `launch-cadence.sh` — routine session: mount sshfs + SSH X11 into the
  server + source `sourceme.ee4615` + `virtuoso &`.
- `mount-tsmcBCD.sh` / `unmount-tsmcBCD.sh` — sshfs control.
- `register-library.sh LIBNAME ...` — appends `DEFINE` lines to `cds.lib`
  for new libraries created in Cadence.
- `run-testbench.sh {binary|thermometer}` — runs the OCEAN sweep on the
  remote and pulls results into `./results/`.

## Math notation in this repo (overrides parent `CLAUDE.md`)

The parent workspace `CLAUDE.md` says "always use Unicode for math".
**For this repo we use LaTeX** (`$...$` inline, `$$...$$` display) per the user's
explicit instruction. Apply that to every `.md` under `project/` and to any
new docs added here. Unicode subscripts/superscripts inside plain code
fences (ASCII diagrams, OCEAN snippets) are fine.

## What I should NOT do without asking

- Don't run `start.ee4615` (or `start`) on the remote — it would overwrite
  the existing `cds.lib` and wipe the EE4610 / SMPC / Tutorial libraries
  the user still has registered. `first-time-setup.sh` copies the
  EE4615-only `sourceme.ee4615` directly instead.
- Don't delete or move folders in `~/tsmcBCD/` on the remote — the home dir
  is NFS-shared with the user's other course work.
- Don't change schematics inside the `Testbench` library — the EE4615
  brief forbids it. Only the `TDC` cell is the user's design surface.
- Don't commit credential files, `tsmcBCD/` (the mount), or large sim
  output (`*.psf*`, `*.raw`, `*.dat`) — `.gitignore` already covers these.

## Useful course facts

- TSMC 180 nm BCD process, nominal $V_{DD} = 1.8\,\text{V}$.
- Transistors are `nmos2v`, `nmos5v`, `pmos2v`, `pmos5v`; technology library is `tsmc18`.
- Corner sections in the model file are `tt_lib`, `ss_lib`, `ff_lib`,
  `sf_lib`, `fs_lib` (plus `mc_lib`, `mismatch_lib` for Monte Carlo).
- License server: `29020@flexserv15.tudelft.nl` (set by `sourcemecadence.ee4615`).
- Cadence IC version on this server: 23.10 (per `sourcemecadence.ee4615`).

## Deadlines

- Topic chosen: 29 Apr 2026 (done — 2-D Vernier, Group 22).
- Final presentation: 8 – 12 Jun 2026.
- Report + Cadence design submission: **15 Jun 2026**.
