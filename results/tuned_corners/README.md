# TB_TDC — five corners WITH per-corner MOSCAP-bank calibration

Companion to [`../corners/`](../corners/README.md) (same methodology, same
$1.5\,\text{ps}$ step, same sign-off checks) — but here each corner runs with
its **own trim-bank setting**, demonstrating the calibration scheme that
`delay_progress.md` §4 designed: switched MOSCAP banks re-centering
$t_0 = \tau_1 - \tau_2$ at $15\,\text{ps}$ in every process corner.
**Calibration is gate-voltage-only** (`trim_x_t1/t2` $\in \{0, 1.8\,\text{V}\}$):
no device changes, so $\Sigma W = 1305.6\,\mu\text{m}$ is identical to the
untuned run and the comparison is apples-to-apples.

## How the configs were found

`tune_probe.ocn` sweeps **all 64 on/off combinations** of the six bank gates
per corner (one short transient each, 320 sims), measuring the stage delays
directly on the internal tap nets — the same expressions as the TB_TDC maestro
outputs: $\tau_1$ = `cross(/I7/I14/tau1)` − `cross(/I7/I14/start_in)`, idem
$\tau_2$. The config with $t_0$ closest to $15\,\text{ps}$ (tie-break:
$\tau_1$ closest to $90\,\text{ps}$) wins; full staircases then validate
end-to-end. Chosen configs (gate voltages, $\tau_1$ banks / $\tau_2$ banks,
bank sizes 2/20/21 resp. 2/14/18 nf-units):

| corner | $\tau_1$ banks (0/1/2) | $\tau_2$ banks (0/1/2) | $\tau_2$ code $b_2b_1b_0$ | probe $\tau_1/\tau_2$ (ps) | probe $t_0$ |
|---|---|---|---|---|---|
| tt | off **on** off | off **on** off | 010 | 88.5 / 73.4 | 15.04 |
| ss | **on** off off | **on** off off | 001 | 93.0 / 78.0 | 14.91 |
| ff | **on on on** | **on on on** | 111 | 90.5 / 75.6 | 14.97 |
| sf | off off **on** | **on on** off | 011 | 89.8 / 74.7 | 15.07 |
| fs | **on on** off (= default) | **on on** off (= default) | 011 | 92.6 / 77.6 | 15.01 |

**Independent cross-check:** these agree with the hand-derived per-corner
$\tau_2$ codes from the design notebook (J., 10 Jun: FF→111, SF→011, TT→011,
FS→010, SS→000 in $b_2b_1b_0$ notation, "untuned = default = 011") — same
direction in every corner, within one bank step. The notebook tuned only the
$\tau_2$ side to $\tau_2 \approx 75\,\text{ps}$; the exhaustive probe co-tunes
both lines for $t_0 = 15\,\text{ps}$, hence the small differences. Two
independent methods, one calibration table.

## Tuned vs untuned — the comparison

| corner | LSB untuned (ps) | **LSB tuned (ps)** | DNL unt / tun (LSB) | INL unt / tun (course, LSB) | E/conv tuned (pJ) | ENOB unt / tun | FoM unt / tun (pJ/step) |
|--------|------|------|-----------|-----------|--------|-----------|-----------|
| tt | 15.35 | **15.00** | 0.66 / 0.70 | 0.65 / 0.60 | 11.64 | 4.54 / 4.57 | 0.50 / 0.49 |
| ss | 18.20 | **15.85** | 0.90 / 0.89 | 0.76 / 0.74 | 10.68 | 4.39 / 4.40 | 0.51 / 0.50 |
| ff | 13.10 | **15.30** | 0.72 / 0.67 | 0.58 / 0.54 | 12.96 | 4.58 / 4.62 | 0.54 / 0.53 |
| sf | 15.35 | **15.25** | 0.66 / 0.67 | 0.61 / 0.67 | 11.95 | 4.57 / 4.52 | 0.50 / 0.52 |
| fs | 15.70 | **15.70** | 0.72 / 0.72 | 0.61 / 0.61 | 11.38 | 4.56 / 4.56 | 0.48 / 0.48 |

**Headlines:**

- **LSB corner spread: $5.10\,\text{ps} \to 0.85\,\text{ps}$ — 6× tighter.**
  All corners land in $15.0\dots15.85\,\text{ps}$; worst-case margin to the
  $20\,\text{ps}$ spec grows from $1.8$ to $4.15\,\text{ps}$.
- **DNL/INL are essentially unchanged** — as expected: calibration re-centers
  the *average* step $t_0$; the period-6 column-wrap sawtooth (see
  `../corners/README.md`) is architectural and survives. Calibration fixes
  resolution drift, not linearity shape.
- fs's optimum **is** the default config — an honest data point (its corner
  shifts N and P oppositely and nearly cancels).
- The stage-level probe slightly underestimates the staircase LSB
  (e.g. ss $14.91 \to 15.85\,\text{ps}$ measured): grid loading beyond the
  first stage adds a corner-dependent few-percent — which is exactly why the
  full staircase validation matters.
- All five corners still PASS every sign-off check (no missing codes,
  monotonic, thermometer intact).

## The graphs

- **`lsb_tuned_vs_untuned.png`** — the headline bar chart: grey = fixed TT trim,
  blue = per-corner calibration, with the $15\,\text{ps}$ target and
  $20\,\text{ps}$ spec lines.
- **`calibration_range.png`** — calibration authority: stage-level $t_0$ vs the
  engaged-capacitance imbalance $\Delta_{cap}$ for all $64\times5$ probe
  points. Monotonic, $\sim0\dots48\,\text{ps}$ of range, every corner's cloud
  crossing the $15\,\text{ps}$ line — the banks have far more authority than
  the $\pm3\,\text{ps}$ the corners require.
- **`staircase_all_corners.png`, `dnl_per_corner.png`, `inl_per_corner.png`,
  `power_vs_delay.png`** — same four standard views as `../corners/`, now with
  calibration applied; note how the staircases nearly overlay.

## Files

- `tune_probe.ocn` — 64-config calibration probe (env `CORNER`)
- `tune_<corner>.csv` — full probe maps (the calibration-range dataset)
- `chosen_configs.txt` — winning gate-voltage sets (corner, $v_{0..2}^{\tau1}$, $v_{0..2}^{\tau2}$)
- `tdc_tuned_all.ocn` — staircase sweep reading `CORNER` + six `TRIM*` env vars
- `results_<corner>.csv` / `log_<corner>.txt`, merged `results_tdc_therm_tuned.csv` / `log_tdc_therm_tuned.txt`
- `plot_tuned.m` → the six PNGs + `tuned_summary.txt`

## Reproduce

```sh
printf "%s\n" tt ss ff sf fs | xargs -P3 -I{} sh -c \
  'CORNER={} ~/tsmcBCD/.claude-tools/cad-ocean tune_probe.ocn > probe_{}.log 2>&1'
# pick configs (see plot_tuned.m / chosen_configs.txt), then:
cat chosen_configs.txt | xargs -P3 -L1 bash -c \
  'CORNER=$0 TRIM0T1=$1 TRIM1T1=$2 TRIM2T1=$3 TRIM0T2=$4 TRIM1T2=$5 TRIM2T2=$6 \
   ~/tsmcBCD/.claude-tools/cad-ocean tdc_tuned_all.ocn > corner_$0.log 2>&1'
matlab -batch "run('plot_tuned.m')"
```
