# 2-D Vernier TDC — Spec Sheet

All numbers are course-required unless flagged "design choice". Targets are
what we must hit; "stretch" rows are bonuses or quality improvements.

> ⚠️ **Operating point under active sizing** (Joris, [`../delay_progress.md`](../delay_progress.md), 6 Jun 2026):
> under the real replica load the feasible point is trending to $k=6$,
> $\tau_1 = 90$ / $\tau_2 = 75\,\text{ps}$, $t_0 = 15\,\text{ps}$, **10×6 logical
> (10×10 physical)** grid. The $k=4$ / 60–45 ps figures below are the **original
> baseline** — to be reconciled once the loaded delay element is locked
> (~Mon 8 Jun 2026).

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
| Layout                | Not required — schematic + Spectre only                |
| Simulator             | Cadence Spectre                                        |
| Linearity reporting   | DNL, INL across all corners and temperatures           |
| Area metric           | $\sum W$ (sum of transistor widths)                    |
| Power metric          | Average energy per conversion, $E_\text{conv}$ (J/conv) |
| Figure of Merit       | $\mathrm{FoM} = P / t_0$ — lower is better             |

## Design choices we have to make (will fill in as we go)

| Parameter              | Provisional choice    | Notes                                       |
|------------------------|------------------------|---------------------------------------------|
| LSB target $t_0$       | $\approx 15\,\text{ps}$ | Margin under the 20 ps cap                  |
| $\tau_1$ (Start path)  | $= k\,t_0$; 60 ps ($k{=}4$) **if reachable under column load** | TA 3 Jun 2026: each tap drives a column of latches + next stage; other 2-D group needed longer delays + ~32× driver |
| $\tau_2$ (Stop path)   | $= (k-1)\,t_0$; 45 ps if $k{=}4$ holds | Must stay $\tau_2 > 0$ and $\tau_1-\tau_2>0$ across all corners |
| Grid size              | $N_Y = k$, $N_X$ from the bijective routing table | $k{=}4$ → 4×~11; $k{=}9$ → 9×11 (other group). ~32 latches, **one per level, no OR-tree** |
| Arbiter style          | Cross-coupled NAND or sense-amp DFF | Decide after metastability sim |
| Delay-element style    | Current-starved inverter or capacitively-loaded inverter | Sets $\tau_1$ vs $\tau_2$ |
| Reset distribution     | Async clear on every DFF, gated by $40\,\text{ps}$ RESET pulse | Aligned start state |

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
