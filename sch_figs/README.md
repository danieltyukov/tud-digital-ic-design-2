# Schematic figures — annotated index

Cadence screenshots/SVG exports of every custom cell in `vernier2d`
(J. Hoogeweegen, 10 Jun 2026). This file maps each figure to its circuit
content, exact device sizing (from the spectre netlist — ground truth), its
role in the architecture, and the measured results it explains. All devices
`nch`/`pch` (tsmc18 2 V), $L = 180\,\text{nm}$ unless noted.

## `srlatch.{png,svg}` — the arbiter (time comparator)

13 transistors: two cross-coupled 2-input NANDs (each 4 devices, **all
440 n/180 n**, N and P equal), an async-reset NMOS (**2 µ/180 n**, gate=RESET)
pulling the QB-side internal node low, and two inverting output buffers (unit
`Inv`: $W_p/W_n = 440/220\,\text{n}$). Pins `S, R, RESET → Q, QB` —
**active-high, no inverted inputs**: in idle both NAND outputs sit high and the
first rising input wins. Q is the buffered S-side NAND, QB the R-side. After
RESET: Q=0, QB=1.
*Measured:* offset $+149.5\,\text{fs}$, dead zone $<1\,\text{fs}$,
$\tau_{reg}=24.1\,\text{ps}$ → [`../results/metastability/`](../results/metastability/README.md).

## `nand.png` — latch gate

The 2-input NAND used inside `srlatch`: 2× series NMOS + 2× parallel PMOS,
all 440 n/180 n. Equal N/P width balances the S- and R-path strengths —
matters for the arbitration offset staying at fs level.

## `delay_tau1.{png,svg}` — slow (START) delay stage, $\tau_1 = 90\,\text{ps}$

FO=1 inverter pair (input inv $nf = m_1{=}5$, output driver $nf = m_2{=}6$;
unit fingers 440 n PMOS / 220 n NMOS) with the **corner-calibration loading**
on the internal node: a fixed MOSCAP ($nf = \texttt{fine}{=}18$,
$L=250\,\text{n}$) behind an always-on access transistor
($nf = \texttt{fixt}{=}7$), plus **three switchable MOSCAP banks**
($nf = \texttt{trim0/1/2} = 2/20/21$, $L=250\,\text{n}$) gated by the
`trim<0:2>` pins. Pins: `in, out, trim<0:2>, VDD, GND`.
*Why FO=1:* FO=4 pinned the minimum stage delay at 97 ps
(`../delay_progress.md` Phase 1); FO=1 opened the 74–147 ps tuning window.

## `delay_tau2.{png,svg}` — fast (STOP) delay stage, $\tau_2 = 75\,\text{ps}$

Identical topology to `delay_tau1` (same active sizing — twin-cell matching),
lighter bank set: $nf = \texttt{trim0/1/2\_t2} = 2/14/18$. The $\tau_1$:$\tau_2$
= 6:5 ratio comes from loading, not transistor sizing, so both lines track
across corners.
*Measured:* one fixed trim code keeps every corner under the 20 ps spec
([`../results/corners/`](../results/corners/README.md)); per-corner codes
re-center $t_0$ to $15.0\dots15.9\,\text{ps}$, spread 6× tighter
([`../results/tuned_corners/`](../results/tuned_corners/README.md)). The
banks' authority: $t_0$ tunable ~0–48 ps (`calibration_range.png` there).

## `tdc_core.png` / `tdc_core_zoomed.png` — the 2-D Vernier grid

The full core: **11× `delay_tau1`** (START line, 10 logical stages + input),
**7× `delay_tau2`** (STOP line, 6 logical stages + input), **60 `srlatch`
arbiters** — 31 active (one per thermometer level $m$, bijective mapping
$y_m = ((m{-}1) \bmod 6){+}1$, $x_m = (m + 5y_m)/6$, **no OR-tree**) and 29
**DUMMY** latches (visible labels in the zoomed shot) padding every tap to
equal fan-out — the loading equalization that the 1-D row lacks
([`../results/vernier1d_vs_2d/`](../results/vernier1d_vs_2d/README.md):
unequalized taps → LSB doubles to 28.6 ps). Clock-tree style input buffers
(`Inv_10x/20x/40x/80x`) drive START/STOP/RESET distribution; six `vsource`
pins carry the trim-bank gate biases (stand-ins for static config bits).
Pin contract matches the course `td` cell: `RESET/START/STOP, VDD/GND, q1..q32`
(q32 spare).
*ΣW:* 1305.6 µm total (1078.3 active across 1120 devices + 227.3 MOSCAP)
([`../results/corners/sigma_w.txt`](../results/corners/sigma_w.txt)).

## `overview.svg` — top-level block diagram

Hand-drawn overview of the signal path: TDC_in buffering → tdc_core grid →
TDC_out loading, with the `Testbench/TDC` wrapper (instance `I14` =
`vernier2d/tdc_core`) and the supply-ammeter energy node `/I1/VDD` used by
all energy/FoM measurements.

## Cross-reference: figure → report section

| figure | report section | key measured numbers |
|---|---|---|
| srlatch, nand | Design: arbiter choice | dead zone <1 fs, $\tau_{reg}$ 24.1 ps |
| delay_tau1/2 | Design: delay cells + sizing justification | $\tau_1/\tau_2$ = 90.5/75.4 ps TT |
| tdc_core(+zoom) | Design: architecture + routing table | LSB 15.35 ps TT, DNL 0.66 |
| overview | Design: system | E/conv 11.7 pJ, FoM 0.50 pJ/step |
