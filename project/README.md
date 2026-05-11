# EE4615 Project — Group 22

**Architecture:** 2-D Vernier TDC (Time-to-Digital Converter)
**Course:** EE4615 — Digital IC Design II, TU Delft Q4 2026
**Instructors:** Morteza Alavi, Masoud Babaie (ELCA/ERL)
**Member:** Daniel Tyukov (`datyukov`)

## Files in this directory

| File                          | What it contains                                            |
|-------------------------------|-------------------------------------------------------------|
| `01-architecture.md`          | The 2-D Vernier idea — why two orthogonal arrays            |
| `02-specs.md`                 | Numeric spec sheet pulled from the EE4615 brief             |
| `03-testbench.md`             | TB_TDC structure, signals, OCEAN sweep, energy formula      |
| `04-implementation-plan.md`   | What we are building, in order, and the open questions      |
| `05-deliverables.md`          | Submission checklist + report/presentation structure        |
| `06-references.md`            | Papers and book chapters that anchor the design             |

## Deadlines

| Item                                 | Date                |
|--------------------------------------|---------------------|
| Topic chosen (2-D Vernier, max 2 grp)| Wed 29 April 2026   |
| Final presentation                   | 8 – 12 June 2026    |
| Report + Cadence design submission   | Mon 15 June 2026    |

Late penalty: −0.1/day, capped at −1.0.

## Grading

50 % design · 25 % presentation · 25 % report.

## Quick-start (this repo)

```bash
# 1. one-time bootstrap (uploads Testbench, makes ~/simulation, ~/tmp, ~/sims)
./first-time-setup.sh

# 2. routine session — opens Cadence Virtuoso on EE4615 via SSH X11
./launch-cadence.sh

# 3. running the OCEAN parametric sweep after the schematic is wired up
./run-testbench.sh binary       # 5-bit binary readout
./run-testbench.sh thermometer  # 31-bit thermometer readout
```
