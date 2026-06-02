# Implementation plan — building the 2-D Vernier TDC

Order is chosen so each step ends in something we can simulate before
moving on. Each phase ends with a "sign off when" criterion.

## Phase 0 — environment ✅

- `first-time-setup.sh` succeeded (Testbench uploaded, `sourceme.ee4615` in place).
- `launch-cadence.sh` opens Virtuoso on `ee4615.ewi.tudelft.nl`.
- `tsmcBCD/` sshfs-mounted into this repo so we can git-track designs.

## Phase 1 — cells (reuse first, build only what's missing)

> Detailed click-by-click in [`08-build-test-runbook.md`](08-build-test-runbook.md).

Two libraries instead of one — **don't redraw the inverters**:

- **Reuse `Testbench`** for the inverters: `Inv`, `Inv_2x`, `Inv_3x`, `Inv_5x`
  are hand-built CMOS at the unit $W_p/W_n = 440/220\,\text{nm}$,
  $L=180\,\text{nm}$ (see [`../tesbench-pics/testbench-schematics-extracted.md`](../tesbench-pics/testbench-schematics-extracted.md)).
  Instantiate them; they are *not* `tsmc18` digital std-cells.
- **Build in our `tdc_2d_vernier`** (`register-library.sh tdc_2d_vernier`) only
  the cells the library lacks. All custom cells use `nmos2v`/`pmos2v`.

| Cell             | Build / reuse        | What |
|------------------|----------------------|------|
| `Inv`,`Inv_2x`,`Inv_3x`,`Inv_5x` | **reuse Testbench** | delay-tap inverters, clock/output buffers |
| `srlatch`        | **build** (keystone) | symmetric SR-latch time comparator (cross-coupled `nand2`, paper Fig. 8) + async RESET |
| `delay_tau1`     | **build**            | 2× reused `Inv` + small MOS-cap/fan-out load → $\tau_1\approx60\,\text{ps}$, non-inverting |
| `delay_tau2`     | **build**            | identical topology, lighter load → $\tau_2\approx45\,\text{ps}$ |
| `nand2`,`nor2`   | **build**            | latch + diagonal OR-tree gates |
| `or_tree`        | **build**            | balanced OR reduction per diagonal level |
| `tdc_core`       | **build**            | 2 delay lines + arbiter grid + OR-tree; **pins identical to `td`** |

`tdc_core` carries the exact `td` pin contract (`RESET/START/STOP`, `VDD/GND`,
`q1..q32`; `q1..q31` thermometer, `q32` spare) and is dropped into the `TDC`
wrapper by **re-pointing instance `I13` (`td` → `tdc_core`)**, keeping the
supply ammeters (energy node `/I1/VDD`) and the provided testbench intact.

**Sign off:** `srlatch`, `delay_tau1`, `delay_tau2` each DC + transient + Monte-
Carlo simulated; $\tau_1\approx60$, $\tau_2\approx45\,\text{ps}$ in TT@27 °C and
$\tau_2>0$ in FF@−40 °C.

## Phase 2 — single Vernier row (1-D sanity check)

Wire 8 `delay_tau1` cells (Start) against 8 `delay_tau2` cells (Stop) with
arbiters in between. Verify:
- Code monotonically rises with `delay` from $0$ to $8\,t_0$.
- LSB measured is $\tau_1 - \tau_2$ (extract via OCEAN sweep step = $1\,\text{ps}$).
- DNL / INL of the 1-D version is sane.

This catches matching / arbiter problems early, on a much smaller circuit.

**Sign off:** $|\mathrm{DNL}| < 0.5\,\text{LSB}$ in TT.

## Phase 3 — 2-D grid

Replicate the 1-D row into a full $8 \times 8$ grid of arbiter cells. Add
the diagonal OR-tree that maps the 2-D occupancy pattern into 31
thermometer outputs.

**Sign off:** TB_TDC sim runs in TT, delay sweep covers all $32$ codes.

## Phase 4 — corners + temperature

Use OCEAN sweep with $\texttt{corners} = \;\texttt{`("tt" "ss" "ff" "snfp" "fnsp")}$
and temperature sweep $T \in \{-40, 27, 150\}^\circ\text{C}$. Resize delay
cells if $\tau_2$ goes negative in FF / $-40^\circ\text{C}$.

**Sign off:** all five corners × three temperatures pass —
no missing codes ($\mathrm{DNL}[k] > -1\,\text{LSB}\;\forall k$), LSB stays
under $20\,\text{ps}$.

## Phase 5 — energy / FoM

Per-conversion energy from OCEAN script. Compute

$$
\mathrm{FoM} = \frac{P_\text{avg}}{t_0} = \frac{E_\text{conv}\,f_\text{conv}}{t_0}.
$$

**Sign off:** numbers locked into a results table for the report.

## Phase 6 — report + presentation

- Slides: $\sim 10\,\text{min}$, both members must present technical content.
- Report: title page → abstract → intro → design → results → conclusion → refs → appendix.
- All Cadence sim plots exported through MATLAB.

Deadline: presentation 8–12 June 2026, report + design 15 June 2026.

## Risks worth keeping a list of

1. **$\tau_2$ collapses negative in FF**: would invert the Vernier action.
   Mitigation: size with $> 5\,\text{ps}$ headroom over corners.
2. **Arbiter metastability** at the smallest $\Delta t$: characterise the
   "dead zone" and report it honestly.
3. **OR-tree skew** makes high-numbered codes lag low-numbered ones:
   balance the depths or buffer.
4. **Crosstalk** between rows / columns when 64 wires run in parallel
   (schematic-level — even without layout, signal integrity affects sim).
