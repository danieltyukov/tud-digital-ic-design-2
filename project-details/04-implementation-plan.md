# Implementation plan — building the 2-D Vernier TDC

Order is chosen so each step ends in something we can simulate before
moving on. Each phase ends with a "sign off when" criterion.

## Phase 0 — environment ✅

- `first-time-setup.sh` succeeded (Testbench uploaded, `sourceme.ee4615` in place).
- `launch-cadence.sh` opens Virtuoso on `ee4615.ewi.tudelft.nl`.
- `tsmcBCD/` sshfs-mounted into this repo so we can git-track designs.

## Phase 1 — primitive cells

Build inside a new library `tdc_2d_vernier` (use `register-library.sh tdc_2d_vernier` after the lib exists on the server). All cells use `nmos2v`/`pmos2v` from `tsmc18`.

| Cell                | What                                                     |
|---------------------|----------------------------------------------------------|
| `inv_min`           | Min-sized CMOS inverter ($W_n \approx 220\,\text{nm}$, $W_p \approx 440\,\text{nm}$) |
| `inv_2x`, `inv_3x`  | Scaled drivers for fan-out                                |
| `nand2`, `nor2`     | For arbiter latch + OR-tree                              |
| `delay_tau1`        | Inverter pair, lightly capped, sets $\tau_1$             |
| `delay_tau2`        | Inverter pair, less capped, sets $\tau_2$ ($\tau_2 < \tau_1$) |
| `arbiter_dff`       | Sense-amp style D-FF with async reset                    |
| `tree_or4`          | 4-input OR for reducing diagonal levels                  |

**Sign off:** every cell DC-sweep + transient simulated, sized to give the
target $\tau_1 \approx 60\,\text{ps}$ and $\tau_2 \approx 45\,\text{ps}$ in
TT @ $27^\circ\text{C}$.

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
