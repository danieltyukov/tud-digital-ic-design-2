# SR-latch arbiter — metastability characterization

**Cell:** `vernier2d/srlatch` (cross-coupled NAND time comparator + async RESET + output buffers), measured through `vernier2d/srlatch_tb`.
**Conditions:** TT corner, $27\,^\circ\text{C}$, $V_{DD} = 1.8\,\text{V}$, $5\,\text{fF}$ loads on Q/QB.
**Date:** 10 Jun 2026. Tools: headless OCEAN/Spectre (`cad-ocean`), plots via MATLAB.

## Why this measurement exists

The arbiter is the decision element of the 2-D Vernier TDC: at every grid node it
decides whether the START or STOP edge arrived first. Its two failure modes set
the noise floor of the whole converter:

1. **Dead zone** — a band of input time differences $\Delta t$ where the output is
   ambiguous (neither rail). Must be $\ll$ LSB ($15\,\text{ps}$).
2. **Metastability** — near-balanced inputs make the decision *time* diverge as
   $t_{dec} \approx t_0 + \tau_{reg}\,\ln\!\frac{1}{|\Delta t - \Delta t_0|}$.
   If $t_{dec}$ exceeds the conversion window, a code read too early is wrong.

## Method

The testbench drives S with an edge at $t_S = 200\,\text{ps}$ (desVar `tds`) and R
at $t_R = t_S + \Delta t$ (desVar `tdr`), $5\,\text{ps}$ edge ramps, after a
$0\to40\,\text{ps}$ RESET pulse. After reset $Q=0$; if S leads ($\Delta t > 0$) the
latch fires $Q \to 1$, if R leads it holds $Q = 0$. Per point we record the final
Q/QB values and the time Q crosses $V_{DD}/2$ (Spectre `cross()`).

Three nested sweeps (49 sims total), each refining the previous:

| pass | file | grid | purpose |
|---|---|---|---|
| coarse | `meta_sweep_coarse.ocn` → `meta_coarse.csv` | $\pm20\,\text{ps} \dots \pm20\,\text{fs}$, log-spaced, 21 pts | bracket the flip, polarity check |
| fine | `meta_sweep_fine.ocn` → `meta_fine.csv` | $0.10\dots0.30\,\text{ps}$, $10\,\text{fs}$ step, 21 pts | localize boundary, divergence branch |
| ultra | `meta_sweep_ultra.ocn` → `meta_ultra.csv` | $141\dots149\,\text{fs}$, $1\,\text{fs}$ step, 9 pts | pin $\Delta t_0$ to $\pm0.5\,\text{fs}$ |

## Results

| metric | value | meaning |
|---|---|---|
| Arbitration offset $\Delta t_0$ | $+149.5 \pm 0.5\,\text{fs}$ | S must lead by this much to fire; $\approx 1\%$ of LSB |
| Dead zone | $< 1\,\text{fs}$ (grid-limited) | every point resolved to a clean rail by $1.95\,\text{ns}$ |
| Regeneration constant $\tau_{reg}$ | $24.1\,\text{ps}$ | from fit $t_{dec} = 148 - 24.1\,\ln(\Delta t')\ \text{ps}$ |
| Nominal clk-Q (large overdrive) | $\approx 102\,\text{ps}$ | flat tail of the curve |
| Worst observed $t_{dec}$ | $347.5\,\text{ps}$ at $0.5\,\text{fs}$ overdrive | still far inside the conversion window |

**Verdict:** dead zone is $>4$ orders of magnitude below the $15\,\text{ps}$ LSB and
the offset is $\sim1\%$ of LSB — the arbiter is not a limiting factor. The honest
caveat for the report: the dead-zone bound is simulation-grid-limited (no noise /
mismatch in this run; Monte-Carlo would widen it), and the numbers are TT-only.

## The graphs

- **`metastability_curve.png`** — decision time $t_{dec}$ (from the arbitration
  instant, $202.5\,\text{ps}$ = mid of the S ramp) vs input overdrive
  $\Delta t - \Delta t_0$ on a log axis. The straight-line region over $\sim3.5$
  decades is the classic metastability signature; its slope is $\tau_{reg}$. The
  flattening right of $\sim5\,\text{ps}$ is the intrinsic clk-Q delay; the bend-up
  at the far left ($<1.5\,\text{fs}$) is $\Delta t_0$-uncertainty, excluded from the fit.
- **`deadzone_transfer.png`** — final Q value vs $\Delta t$: a razor step at
  $\Delta t_0 = +0.1495\,\text{ps}$, flipping between adjacent $1\,\text{fs}$ grid
  points with no intermediate (metastable) final values observed.

## Reproduce

```sh
~/tsmcBCD/.claude-tools/cad-ocean meta_sweep_coarse.ocn   # then fine, then ultra
matlab -batch "run('plot_meta.m')"
```
