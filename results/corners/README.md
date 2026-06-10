# TB_TDC — five-corner process sweep (Phase 4) + energy/FoM (Phase 5)

**DUT:** `Testbench/TB_TDC` → `TDC` wrapper → `vernier2d/tdc_core` (2-D Vernier,
$k=6$, logical $10\times6$ grid, 60 SR-latch arbiters incl. dummies).
**Conditions:** $27\,^\circ\text{C}$, $V_{DD}=1.8\,\text{V}$, corners
`tt ss ff sf fs` (this PDK's section names; `sf` = snfp, `fs` = fnsp).
**Date:** 10 Jun 2026, 1670 transients total, $1.5\,\text{ps}$ delay step
($\approx$ resolution/10).

## Methodology — and the one deliberate choice

`tdc_corners_all.ocn` is the course `testbench_tdc_therm.ocn` with its math and
sign-off checks untouched; only adapted to this machine (muse/BCDG2 model path,
`*_lib` section names, netlisting from the schematic, per-corner parallel
execution via the `CORNER` env var with isolated project dirs).

**All five corners use one fixed trim configuration** — the tuned TT maestro
state (`trim0=2, trim1=20, trim2=21, fine=18, trim0_t2=2, trim1_t2=14,
trim2_t2=18`, $m_1=5$, $m_2=6$, `m_inv_in=10`). This is the *uncalibrated
robustness* result: it shows the TDC meets spec across process **without
touching the calibration**, at the cost of the LSB breathing with the corner
instead of being held at $15\,\text{ps}$. The MOSCAP banks could re-center
$t_0$ per corner (desVar-only change); not needed for the $<20\,\text{ps}$ spec,
so not exercised. Phrase it that way in the report.

The sweep raises `delay` from $-15\,\text{ps}$ in $1.5\,\text{ps}$ steps until
code 31, recording every code transition, then continues $\sim$15% further for
the energy average. Energy integrates the `/I1/VDD` supply ammeter over each
$5\,\text{ns}$ window: $E = V_{DD}\!\int |i|\,dt$.

## Summary (sign-off: no missing codes, monotonic, LSB < 20 ps — ALL PASS)

| corner | LSB (ps) | DNL$_{max}$ (LSB) | INL course / endpoint (LSB) | offset (ps) | E/conv (pJ) | ENOB | FoM (pJ/step) |
|--------|---------|------|--------------|--------|---------|------|------|
| tt | 15.35 | 0.66 | 0.65 / 0.80 | −15.4 | 11.67 | 4.54 | 0.50 |
| ss | 18.20 | 0.90 | 0.76 / 1.04 | −24.2 | 10.76 | 4.39 | 0.51 |
| ff | 13.10 | 0.72 | 0.58 / 0.62 | −7.1 | 12.84 | 4.58 | 0.54 |
| sf | 15.35 | 0.66 | 0.61 / 0.72 | −13.9 | 11.96 | 4.57 | 0.50 |
| fs | 15.70 | 0.72 | 0.61 / 0.70 | −15.7 | 11.38 | 4.56 | 0.48 |

Two INL conventions appear: *course* is the script's half-range
$(\text{late}-\text{early})/2t_0$; *endpoint* is the per-code
endpoint-referenced $\max|{\rm INL}[k]|$ from `plot_corners.m`. Quote the course
one for sign-off, show the endpoint curve in the plot.

**Worst case to quote:** ss — $18.2\,\text{ps}$ LSB (closest to the
$20\,\text{ps}$ ceiling) and DNL $0.90$ LSB. Skewed corners barely differ from
tt because the N/P shifts cancel in the inverter pair delay.

## The graphs

- **`staircase_all_corners.png`** — full transfer (code vs delay) per corner.
  All monotonic, all reach code 31; slope spreads with corner speed
  (ff steepest, ss shallowest, full scale $\approx400\dots560\,\text{ps}$).
- **`dnl_per_corner.png`** — per-code DNL. The dominant feature is a
  **systematic period-6 sawtooth**: peaks of $+0.6\dots0.7$ LSB at codes
  7, 13, 19, 25 — exactly the $k=6$ column-wrap boundaries of the 2-D Vernier
  mapping ($m = 6q + r$), where the signal path hands over from a row step to a
  column step. It is identical in every corner ⇒ architectural (path-length
  imbalance at the wrap), not random mismatch. The first transition (codes 2–3)
  shows the largest excursion (boundary effect of the first row).
- **`inl_per_corner.png`** — integral of the above: a period-6 sawtooth riding a
  slow bow, worst in ss.
- **`power_vs_delay.png`** — energy/conversion vs input delay: nearly flat
  ($10.6\to13.0\,\text{pJ}$ band), ordered ss < fs < tt < sf < ff (switching
  energy tracks corner speed); gentle upward slope as more stages toggle at
  larger delays.

## ΣW (transistor area proxy, from the netlist — `sigma_w.txt`)

| group | $\Sigma W$ (µm) | devices |
|---|---|---|
| active NMOS | 474.6 | — |
| active PMOS | 603.7 | — |
| **active total** | **1078.3** | 1120 |
| MOSCAP trim banks | 227.3 | 65 |
| **grand total** | **1305.6** | 1185 |

Dominated by the `delay_tau1` drivers (451 µm / 11 inst.), `nand` latch gates
(211 µm), latch-internal `Inv`s (115 µm). Computed by `sum_width.py` from the
spectre netlist with the tuned variable values; MOSCAPs identified by
drain=source=bulk connection. Note: the six `vsource` instances inside
`tdc_core` are the trim-bank gate biases (`trim_x_t1/t2`) — ideal control
signals standing in for static config bits.

**Per the spec ("$\Sigma W$ as a single number per corner"):** the value is the
**same in all five corners** — $1305.6\,\mu\text{m}$ — because one fixed trim
configuration is used everywhere and trimming only changes MOSCAP gate biases,
never the devices present. Scope (open TA question in `02-specs.md`): core-only
$= 1305.6\,\mu\text{m}$; including the testbench buffer cells (`TDC_in`
$11.9\,\mu\text{m}$ + `TDC_out` $81.8\,\mu\text{m}$) $= 1399.3\,\mu\text{m}$ —
both extracted, quote whichever scope the TA confirms.

## Requirements cross-check (02-specs.md "What gets reported")

| # | requirement | status |
|---|---|---|
| 1 | DNL plot per corner | ✓ `dnl_per_corner.png` |
| 2 | INL plot per corner | ✓ `inl_per_corner.png` |
| 3 | Power vs delay + average $E_{conv}$ | ✓ `power_vs_delay.png` + table |
| 4 | $\Sigma W$ per corner | ✓ $1305.6\,\mu\text{m}$ (identical all corners, see above) |
| 5 | FoM table: best / worst / nominal | ✓ both definitions below |
| 6 | Worst-case dead zone | ✓ $<1\,\text{fs}$ (`../metastability/`) |

**Both FoM definitions** (the spec defines $\mathrm{FoM}=P/t_0$; the course
OCEAN script computes $E_{conv}/2^{\mathrm{ENOB}}$). $P_{avg}$ assumes the sim's
$5\,\text{ns}$ conversion window ($200\,\text{MS/s}$):

| corner | $P_{avg}$ (mW) | $\mathrm{FoM}=P/t_0$ (mW/ps) | $\mathrm{FoM}=E/2^{ENOB}$ (pJ/step) |
|--------|------|-------|------|
| tt (nominal) | 2.33 | 0.152 | 0.50 |
| ss | 2.15 | 0.118 (best) | 0.51 |
| ff | 2.57 | 0.196 (worst) | 0.54 |
| sf | 2.39 | 0.156 | 0.50 |
| fs | 2.28 | 0.145 | 0.48 (best) |

Dynamic range (free from the staircase data): $31 \times \mathrm{LSB} =
406\,\text{ps}$ (ff) $\dots 564\,\text{ps}$ (ss); quantization-limited
single-shot precision $\sigma = \mathrm{LSB}/\sqrt{12} = 3.8\dots5.3\,\text{ps}$.

## Files

- `tdc_corners_all.ocn` — the sweep (env `CORNER=tt|ss|ff|sf|fs` selects corner)
- `smoke_tt.ocn` — 4-point TT validation used to calibrate the run setup
- `results_<corner>.csv` / `log_<corner>.txt` — per-corner transitions + metrics / per-run delay,code,energy
- `results_tdc_therm.csv` / `log_tdc_therm.txt` — canonical merged deliverable (corner blocks in order tt ss ff sf fs)
- `plot_corners.m` — parses both files, renders the four PNGs + `corner_summary.txt`
- `sum_width.py` → `sigma_w.txt`

## Reproduce

```sh
printf "%s\n" tt ss ff sf fs | xargs -P3 -I{} sh -c \
  'CORNER={} ~/tsmcBCD/.claude-tools/cad-ocean tdc_corners_all.ocn > corner_{}.log 2>&1'
matlab -batch "run('plot_corners.m')"
```

(~45 min per corner at $1.5\,\text{ps}$ step, 3 in parallel. Known quirk on
et4382: `cdsXvfb-run` wrappers may hang after OCEAN exits — kill them to free
the xargs slots.)
