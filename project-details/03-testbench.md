# Testbench — TB_TDC

Source: `Testbench_180nm_tech_2026/Testbench_180nm_tech/Testbench/` and
the EE4615 Testbench Instructions PDF (April 2026 revision).

## Hierarchy (Cadence library `Testbench`)

| Module             | Role                                                            |
|--------------------|------------------------------------------------------------------|
| **TB_TDC**         | Top — wires TDC_in → TDC → TDC_out and connects the Power block. |
| **TDC_in**         | Generates RESET ($40\,\text{ps}$ fixed pulse), START, STOP from `delay`. Internally buffered with $3\times$ min-Inv. |
| **TDC**            | **YOUR** design goes here: $\{\text{Start, Stop, Reset}, V_{DD}, \text{GND}\} \to Q_1..Q_{31}$ (thermometer) or $Q_1..Q_5$ (binary). |
| **TDC_out**        | Registers / fan-out for the TDC outputs. Each output drives $5\times$ min-Inv. |
| **POWER**          | Supplies $V_{DD}$ (set by `supply` variable in ADE) and GND. Current-sense node for energy. |
| **Inv**, **Inv_2x**, **Inv_3x**, **Inv_5x**, **Inv_20x** | Hand-built CMOS inverters of various drive strengths. |
| **Mux**, **txg**   | Building blocks for the old 5-bit T2B decoder (`5_bit_T2B`). Decoder is no longer used. |

⚠️ Per the instruction sheet: **do not edit any schematic in the Testbench
library**. Only modify ADE variables (`delay`, `supply`, reset pulse width, etc.)
and the contents of the `TDC` block.

## How the input stimuli are driven

- $\text{RESET}$: fixed $40\,\text{ps}$ positive pulse, synchronous *before*
  START/STOP. Asserts the DFFs into a known state. Drive strength = $3\times$ min inverter.
- $\text{START}$: rising edge at $t = t_\text{start}$.
- $\text{STOP}$: rising edge at $t = t_\text{start} + \texttt{delay}$.

`delay` is the ADE variable swept by the OCEAN parametric sweep, so the
TDC sees

$$
\Delta t = t_\text{stop} - t_\text{start} = \texttt{delay}.
$$

## Power / energy measurement

The Power block has its own VDD pin (separate from the testbench supply
$V_{DD,\text{TB}}$) so only the TDC core current is measured.

Energy formula entered in ADE → Outputs → Setup:

$$
E_\text{conv} = \int_{0}^{t_\text{sim}}\; -\;V_T\!\left(\texttt{/VDD}\right)\cdot I_T\!\left(\texttt{/I1/VDD}\right)\;dt
$$

Equivalent OCEAN expression:

```
energy = integ(- (VT("/VDD") * IT("/I1/VDD")) 0 sim_time)
```

- `sim_time` is whatever Stop-Time you set for the transient (e.g. `1n`).
- `I1` is the TDC instance name in TB_TDC; `/I1/VDD` is the current-sense node.

For the OCEAN scripts, energy is summed across the parametric sweep and
written to `~/simulation/results_tdc_*.csv`.

## OCEAN testbench scripts

Two pre-built scripts live in `~/tsmcBCD/` on the server:

| Script                       | What it measures                                     |
|------------------------------|------------------------------------------------------|
| `testbench_tdc_binary.ocn`   | 5-bit binary output $Q_1..Q_5$                       |
| `testbench_tdc_therm.ocn`    | 5-bit thermometer output $Q_1..Q_{31}$ (codeLimit = 31) |

### Important `desVar`s the script sets

```ocean
Vdd                = 1.8            // supply voltage
timeStep           = 1.0e-12        // parametric delay step (1 ps)
transientSimTime   = 5.5e-9         // 5.5 ns per simulation
startDelay         = 0e-12          // first delay swept
corners            = `("tt")        // change to `("tt" "ss" "ff" "sf" "snfp" "fnsp") for full coverage
codeLimit          = 31             // stop sweep when this code reached
desVar("delayscale" 6)              // input driver scaling
```

> The corner labels $\texttt{snfp}$ (= SF) and $\texttt{fnsp}$ (= FS) are
> handled inside the script's `loadlibs` function — it maps them to
> alternate n/p combinations from the same `c018bcd_gen2_v1d6.scs` model file.

### How to run

```bash
# from this repo, after first-time-setup.sh has been run once:
./run-testbench.sh thermometer   # or: binary
```

That script:
1. SSHes into `ee4615`, sources `sourceme.ee4615`, starts `ocean`.
2. Loads `testbench_tdc_therm.ocn` (or `_binary.ocn`).
3. Pulls back `results_tdc_*.csv` and `log_tdc_*.txt` into `./results/`.

The CSV gives per-step measured $\Delta t \to$ output code $\to$ DNL/INL.

## Bench-side cautions copied from the brief

- **Every** schematic and symbol must carry a `VDD` and `GND` pin (NOT a
  global net). Connect those to the POWER block of TB_TDC. Do not use
  global VDD/GND anywhere in your TDC.
- The `5_bit_T2B` decoder is **no longer used** — leaving it in is fine,
  the OCEAN scripts measure thermometer outputs directly.
- If ADE complains about `Cannot create directory: /data/simdir/...`,
  change the simulation results path to `~/sims/` (already pre-created by
  `first-time-setup.sh`).
