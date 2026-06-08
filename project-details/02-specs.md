# 2-D Vernier TDC — Spec Sheet

All numbers are course-required unless flagged "design choice". Targets are
what we must hit; "stretch" rows are bonuses or quality improvements.

> ✅ **Operating point LOCKED** (8 Jun 2026 — see [`../delay_progress.md`](../delay_progress.md)
> and Joris's 5-corner sims): under the real replica load the design sits at
> $k=6$, $\tau_1 = 90$ / $\tau_2 = 75\,\text{ps}$, $t_0 = 15\,\text{ps}$,
> **10×6 logical (10×10 physical)** grid, SR-latch arbiter (not D-FF). The
> earlier $k=4$ / 60–45 ps figures were the pre-load baseline and are
> superseded — the design-choices table below now reflects the locked values.

## Hard requirements (must pass, all from EE4615 brief)

| Parameter             | Target                                                |
|-----------------------|--------------------------------------------------------|
| Output bits           | **5**                                                  |
| Time resolution (LSB) | $t_0 < 20\,\text{ps}$                                  |
| Full range            | $32\,t_0$ (5-bit linear)                               |
| Output coding         | Thermometer ($Q_1..Q_{31}$) — binary readout exists but unused for grading |
| Process               | TSMC 180 nm BCD (`tsmc18`, `nmos2v`/`pmos2v`)          |
| Nominal $V_{DD}$      | $1.8\,\text{V}$                                        |
| Corners               | $\{\text{TT}, \text{FF}, \text{SS}, \text{SF}, \text{FS}\}$ |
| Temperature           | $-40^\circ\text{C}$ to $+150^\circ\text{C}$ — *TA session 3 Jun 2026: possibly corners-only, no temp sweep; confirm* |
| Standard cells        | **None** — every gate hand-built                       |
| Inputs                | RESET ($40\,\text{ps}$ pulse), START, STOP — each via $3\times$ min-Inv |
| Output loading        | $5\times$ min-inverter per $Q$-line *(actual TB schematic: $2\times$ `Inv_2x` + 1 fF — see `../tesbench-pics/testbench-schematics-extracted.md`)* |
| Single ground         | One reference; $V_{DD}, V_{SS}$ built on top           |
| Supply domains        | DUT on its own $V_{DD}$ (0 V series ammeter → energy node `/I1/VDD`); stimulus buffers on a **separate** $V_{DD\_TB}$ so only DUT current is measured (Test Bench slide) |
| Layout                | Not required — schematic + Spectre only                |
| Simulator             | Cadence Spectre                                        |
| Linearity reporting   | DNL, INL across all corners and temperatures           |
| Area metric           | $\sum W$ (sum of transistor widths)                    |
| Power metric          | Average energy per conversion, $E_\text{conv}$ (J/conv) |
| Figure of Merit       | $\mathrm{FoM} = P / t_0$ — lower is better             |

## Design choices — LOCKED (8 Jun 2026)

| Parameter              | Choice                 | Notes                                       |
|------------------------|------------------------|---------------------------------------------|
| LSB target $t_0$       | $15\,\text{ps}$        | 5 ps margin under the 20 ps cap; $t_0 = \tau_1 - \tau_2$ |
| Multiplier $k$         | $6 \Rightarrow \tau_1{:}\tau_2 = 6{:}5$ | Sets line lengths and the bijective routing map |
| $\tau_1$ (Start, slow) | $= k\,t_0 = 90\,\text{ps}$ | **10-stage** line (the longer/slower line carries START); each tap drives 6 real latches (col load) |
| $\tau_2$ (Stop, fast)  | $= (k-1)\,t_0 = 75\,\text{ps}$ | **6-stage** line; each tap drives 10 real latches (row load). Must keep $\tau_2>0$ and $\tau_1-\tau_2=15$ ps across all corners |
| Grid size              | **10×6 logical** ($N_X{=}10$ START, $N_Y{=}6$ STOP), **10×10 physical** | Dummy-padded to square so every tap sees fan-out 10 (perfect matching). 31 latches, **one per level, no OR-tree** |
| Arbiter style          | **NAND-based SR latch** + async RESET (built: `vernier2d/srlatch`) | Chosen over D-FF; metastable "dead zone" to be characterised |
| Delay-element style    | Capacitively-loaded inverter, **FO=1** ($\text{Inv}_\text{in}{=}2\times$, $\text{Inv}_\text{out}{=}2\times$) | FO=4 pinned the floor at 97 ps; FO=1 opened a 74–147 ps window |
| Corner tuning          | Transmission-gate–switched **MOSCAP banks** at each tap | Holds $\tau_1-\tau_2 = 15$ ps across SS/TT/FF/SF/FS (see `delay_progress.md` §4) |
| Reset distribution     | Async clear on every latch, gated by $40\,\text{ps}$ RESET pulse | Aligned start state |

> **Line-length vs fan-out (don't conflate):** the **10-stage** cascade is the
> slow $\tau_1$/START line; the **6-stage** cascade is the fast $\tau_2$/STOP line
> (the routing math $t_m = x_m\tau_1 - y_m\tau_2 = m\,t_0$ only closes this way).
> Per-tap **fan-out** is the opposite — a $\tau_2$ tap feeds $N_X{=}10$ latches,
> a $\tau_1$ tap feeds $N_Y{=}6$ — which the 10×10 physical padding equalises.

## DNL / INL definitions (from Lecture 2)

For an ideal step width $t_0$:

$$
\mathrm{DNL}[k] = \frac{w[k] - t_0}{t_0},
\qquad
\mathrm{INL}[k] = \sum_{i=0}^{k} \mathrm{DNL}[i].
$$

We need $\mathrm{DNL}[k] > -1\,\text{LSB}\;\forall k$ — anything below that is
a *missing code*, which fails the linearity requirement.

## What gets reported in the deliverables

1. **DNL plot** (LSB units) across codes $0..31$, per corner and temperature.
2. **INL plot** (LSB units) across codes $0..31$, per corner and temperature.
3. **Power vs delay** sweep, plus average $E_\text{conv}$.
4. **$\sum W$** (μm) as a single number per corner.
5. **FoM table**: best, worst, nominal.
6. **Worst-case "dead zone"** width (smallest resolvable $\Delta t$) —
   important limitation for a 2-D Vernier.

## Open questions to discuss with TAs

- Are the 2-D arbiter cells allowed to share clock-distribution gates with
  adjacent cells, or must each $(i,j)$ be electrically independent?
- For $\sum W$ reporting, do we count the inverters in TDC_in/TDC_out
  (testbench fan-out cells) or only the TDC core?
- Does the bonus "TDC for ADC" (voltage-to-time) count toward the 50%
  design grade or only as a tie-breaker?
