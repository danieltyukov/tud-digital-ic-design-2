# tud-digital-ic-design-2

TU Delft **EE4615 — Digital IC Design II** workspace.
Project: **2-D Vernier Time-to-Digital Converter** — Group 22.

Cadence runs on a remote TU Delft server (`ee4615.ewi.tudelft.nl`); this
repo holds the setup/launch scripts, the supplied Testbench, the official
course PDFs, and the project documentation.

## Quick start

```bash
# 1. one-time bootstrap (uploads Testbench to the server,
#    creates working directories, registers Testbench in cds.lib)
./first-time-setup.sh

# 2. open Cadence Virtuoso (or just click the desktop launcher)
./launch-cadence.sh

# 3. run the supplied OCEAN parametric sweep when the TDC schematic is wired
./run-testbench.sh thermometer    # or: binary
```

The desktop launcher at `~/.local/share/applications/cadence-virtuoso.desktop`
is already routed to this repo's `launch-cadence.sh`.

## Layout

```
.
├── CLAUDE.md                       # repo context for Claude Code
├── README.md                       # this file
├── cadence.png                     # desktop launcher icon
├── password_username.txt           # credentials (gitignored)
├── logins.txt                      # credentials summary (gitignored)
│
├── first-time-setup.sh             # idempotent bootstrap
├── launch-cadence.sh               # open Virtuoso over SSH X11
├── mount-tsmcBCD.sh                # sshfs ~/tsmcBCD -> ./tsmcBCD
├── unmount-tsmcBCD.sh              # release the mount
├── register-library.sh             # add DEFINE entries to cds.lib
├── run-testbench.sh                # run OCEAN testbench on the server
│
├── delay_progress.md               # live delay-line sizing log (current τ/grid source of truth)
│
├── tutorials/                      # official EE4615 PDFs
│   ├── Cadence First Use Tutorial 2026.pdf
│   ├── EE4615_Instruction_Manual_2026.pdf
│   ├── EE4615 Testbench Instructions 2026.pdf
│   └── EE4615_Corner_analysis_2026.pdf
│
├── Testbench_180nm_tech_2026/      # supplied Cadence Testbench library
│   └── Testbench_180nm_tech/
│       ├── Testbench/              # Cadence library (TB_TDC, TDC_in, TDC_out, …)
│       ├── testbench_tdc_binary.ocn
│       └── testbench_tdc_therm.ocn
│
├── project-details/                # our project documentation + anchor-paper PDFs
│   ├── README.md
│   ├── 01-architecture.md
│   ├── 02-specs.md
│   ├── 03-testbench.md
│   ├── 04-implementation-plan.md
│   ├── 05-deliverables.md
│   ├── 06-references.md
│   ├── 07-paper-2d-vernier-design-notes.md
│   ├── 08-build-test-runbook.md
│   └── *.pdf                       # MAIN_2D_VERNIER + 1D_VERNIER ×2 + BASIC_FLASH
│
├── tesbench-pics/                  # extracted Testbench schematics + cell map
├── tsmcBCD/                        # sshfs mount of remote ~/tsmcBCD (gitignored)
└── results/                        # OCEAN result CSVs (gitignored or kept, your call)
```

## How the remote login works

- Server: `ee4615.ewi.tudelft.nl`
- Credentials read from `password_username.txt` (gitignored). Format:
  ```
  login: datyukov
  password: <yourpassword>
  ```
- Every shell script parses this with `grep '^login:' | awk '{print $2}'` —
  keep the format.

## Math notation in this repo

`.md` files under `project-details/` use **LaTeX** math (`$...$`, `$$...$$`),
overriding the parent workspace's Unicode-math rule. Most renderers
(GitHub, VS Code preview, Obsidian) handle this natively.

## Course deadlines

| Item                                | Date              |
|-------------------------------------|-------------------|
| Topic chosen (2-D Vernier, Group 22)| 29 Apr 2026 ✅     |
| Final presentation                   | 8 – 12 Jun 2026   |
| Report + Cadence design submission   | **15 Jun 2026**   |
