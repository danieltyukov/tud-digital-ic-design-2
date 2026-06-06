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
| `delay_tau1`     | **build**            | 2× reused `Inv` + node-A load + **strong output driver**; $\tau_1=k\,t_0$ sized **under replica column load** (TA 3 Jun) |
| `delay_tau2`     | **build**            | identical topology, lighter load → $\tau_2=(k-1)\,t_0$ |
| `nand2`          | **build**            | latch gate (`nor2`/`or_tree` **dropped** — bijective routing, no OR-tree) |
| `tdc_core`       | **build**            | 2 delay lines + arbiter grid + direct output routing; **pins identical to `td`** |

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

Build the grid from the **bijective routing table** ($N_Y=k$ Stop stages,
$N_X$ Start stages; one `srlatch` per level $m$ at
$y_m=((m-1)\bmod k)+1$, $x_m=(m+(k-1)y_m)/k$ — see
[`08-build-test-runbook.md`](08-build-test-runbook.md) Phase 4a). Route each
latch output **directly** to its thermometer pin — **no OR-tree** (TA session
3 Jun 2026). Add dummy latch-input loads so every tap carries equal fan-out.

**Sign off:** TB_TDC sim runs in TT, delay sweep covers all $32$ codes.

## Phase 4 — corners + temperature

Use OCEAN sweep with $\texttt{corners} = \;\texttt{`("tt" "ss" "ff" "snfp" "fnsp")}$.
**TA session 3 Jun 2026: temperature sweep possibly not required (corners only)
— confirm before running** $T \in \{-40, 27, 150\}^\circ\text{C}$. Resize delay
cells if $\tau_2$ goes negative in the fast corner.

**Sign off:** all required corner (× temperature, if confirmed) runs pass —
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
3. **Per-tap fan-out loading**: every tap drives a column of latch inputs +
   the next delay stage. Sizing the delay without that replica load gives a
   fictitious $\tau$ — the other 2-D group lost their 45/60 ps target to this
   and ended at a 9×11 matrix with ~32× output drivers.
4. **Crosstalk** between rows / columns when 64 wires run in parallel
   (schematic-level — even without layout, signal integrity affects sim).
