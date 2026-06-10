# Speech notes — EE4615 final presentation, Group 22

**Deck:** `EE4615_Group22_2D_Vernier_TDC.pptx` (16 slides)
**Format:** 10 min talk + 5 min Q&A. Speaker switches every slide. ~30 s per
content slide, short sentences, say it and move on. Times are cumulative.

| Slide | Speaker | Topic | Time |
|---|---|---|---|
| 1 | Daniel | Title | 0:00 |
| 2 | Daniel | The brief | 0:15 |
| 3 | Joris | Why 2-D Vernier | 0:45 |
| 4 | Daniel | Architecture, $k=6$ | 1:15 |
| 5 | Joris | Delay stage | 1:45 |
| 6 | Daniel | SR-latch arbiter | 2:15 |
| 7 | Joris | The loading pivot | 2:45 |
| 8 | Daniel | Build + testbench | 3:15 |
| 9 | Joris | Staircase per corner | 3:45 |
| 10 | Daniel | DNL / INL | 4:15 |
| 11 | Joris | Calibration | 4:45 |
| 12 | Joris | Metastability | 5:15 |
| 13 | Daniel | 1-D vs 2-D measured | 5:45 |
| 14 | Joris | Scorecard | 6:15 |
| 15 | Daniel | Conclusions | 6:45 |
| 16 | Joris | Thank you | 7:15 |

---

## Slide 1 — Title *(Daniel, ~15 s)*

Group 22, Daniel and Joris. A 2-D Vernier time-to-digital converter in 180
nanometers. 15 picoseconds, 5 bits. On the right: our actual core. Everything was
joint work. We switch speakers every slide.

## Slide 2 — The brief *(Daniel, ~30 s)*

Task: START in, STOP in, 5-bit thermometer code out. The cards below: 5 bits,
under 20 picoseconds, five corners, zero standard cells. Every gate hand-built,
1.8 volts, Spectre only. We optimize four things: linearity, energy, transistor
width, figure of merit. Our pick: the 2-D Vernier. It breaks the link between
resolution and range.

## Slide 3 — Why 2-D Vernier *(Joris, ~30 s)*

Vernier: START through slow stages $\tau_1$, STOP chases through fast stages
$\tau_2$. Gain per stage: $t_0 = \tau_1 - \tau_2$. That is the LSB, below one gate
delay. Problem in 1-D: one stage pair per code, 64 stages for 5 bits. In 2-D:
tap $i$ versus tap $j$, each cell measures $i\,\tau_1 - j\,\tau_2$. Table on the
right: 16 stages instead of 64, latency 0.9 versus 3.3 nanoseconds.

## Slide 4 — Architecture *(Daniel, ~30 s)*

Locked at $k = 6$. $\tau_1$ 90 picoseconds, ten stages. $\tau_2$ 75, six stages.
$t_0$ 15, five below spec. Level-to-cell mapping is bijective, formula on the
slide. One latch per level, wired straight out. No OR tree, no skew. 31 active
latches, 29 dummies, a 10 by 10 array: every tap sees the same fan-out. Right:
block diagram, two lines, latch matrix, buffer trees.

## Slide 5 — Delay stage *(Joris, ~30 s)*

Left figure: the $\tau_1$ cell. Fan-out-of-four sizing bottomed out at 97
picoseconds. Fan-out-of-one: 74 to 147. Both lines, identical transistors. The
6 to 5 ratio comes from loading only, so the lines track across corners. On the
internal node: one fixed MOSCAP, three switchable banks, 48 picoseconds of trim
authority. Right: the $\tau_2$ twin.

## Slide 6 — Arbiter *(Daniel, ~30 s)*

Below: cross-coupled NAND SR latch. 13 transistors, all 440 over 180. Both
outputs idle high, first rising edge wins. Equal N and P widths, balanced S and R
paths: offset at femtosecond level. One NMOS resets it in 40 picoseconds. Why not
a D flip-flop? Bigger, asymmetric, heavier reset. Times 60 instances, that
matters.

## Slide 7 — The loading pivot *(Joris, ~30 s)*

Our main lesson. A tap drives a whole row or column plus the next stage: 20 times
load. Sized standalone we predicted 16.6 picoseconds. Measured: 28.6. Factor two,
pure loading. Fix: characterize under a replica load, equalize with dummies,
right figure. This killed $k = 4$ and locked $k = 6$. In a Vernier grid, loading
is architecture.

## Slide 8 — Build + testbench *(Daniel, ~30 s)*

Bottom: the core as built. 18 delay stages, 60 latches, 1120 devices, 1306
micrometers. Course TB_TDC harness. DUT on its own supply behind an ammeter,
stimulus on a separate rail: energy is the converter only. OCEAN sweeps all 32
codes per corner. LSB, DNL, INL, energy, pass or fail, fully automated.

## Slide 9 — Staircase *(Joris, ~30 s)*

Left: measured transfer, five corners, one fixed trim code. Clean 31-step
staircase everywhere. Right table: 13.1 to 18.2 picoseconds, five out of five
PASS. The horizontal shift is static offset, about one LSB, calibrates out. Spec
met before any calibration.

## Slide 10 — DNL / INL *(Daniel, ~30 s)*

Left: DNL. Worst 0.90 LSB in slow-slow, far from minus one: no missing codes,
any corner. Right: INL, worst 1.04 untuned, others under 0.8. See the
six-code period in the DNL: row versus column residual, period equals $k$. The
textbook 2-D Vernier fingerprint. The converter behaves exactly as theory says.

## Slide 11 — Calibration *(Joris, ~30 s)*

Banks on, set once per corner, like config bits. Left chart, gray untuned, blue
calibrated: spread drops 5.1 to 0.85 picoseconds. Six times tighter. Every corner
at 15.0 to 15.9. INL down to 0.74. FoM stays at half a picojoule per step. Right
plot: $t_0$ moves monotonically with engaged capacitance, every corner crosses
the 15 picosecond line. A valid code always exists.

## Slide 12 — Metastability *(Joris, ~30 s)*

We pushed the arbiter to half a femtosecond overdrive, 49 simulations. Left:
decision time curve, regeneration 24.1 picoseconds, worst decision 348, inside
the window. Right: the transfer flips within one femtosecond, four orders below
the LSB. Offset: 0.15 picoseconds, one percent of an LSB. Metastability is not
the limit. The LSB is.

## Slide 13 — 1-D vs 2-D, measured *(Daniel, ~30 s)*

We measured the comparison. Same cells, rebuilt as a 1-D row. Right table: 28.6
versus 15.35 picoseconds, worse DNL, double the width per code. Left plot: scale
to 31 codes and 1-D needs 3.4 times the stages, 1.9 times the area, 3.3
nanoseconds latency versus 0.9. Same cells, same process. The grid wins.

## Slide 14 — Scorecard *(Joris, ~30 s)*

Everything against the brief. Five bits: pass. Resolution 15.0 to 15.9 against
20: pass. Five of five corners: pass. DNL 0.89, no missing codes. INL 0.74.
Energy 10.7 to 13 picojoules. FoM half a picojoule per step. 1306 micrometers.
ENOB 4.4 to 4.6. All from Spectre corner sweeps on the official testbench.

## Slide 15 — Conclusions *(Daniel, ~30 s)*

Summary: all specs met, all corners, the six numbers on the right. Two ideas
carried the design: size under the real grid load, equalize fan-out with dummies.
Calibration is cheap: three MOSCAP banks, six times tighter spread. Next: DLL
background calibration, a voltage-to-time front end for an ADC, layout and
extraction. All of it joint work.

## Slide 16 — Thank you *(Joris, ~10 s)*

That was our 2-D Vernier TDC. Thank you. Questions welcome.

---

## Q&A preparation (5 minutes, either of us answers)

- **Why SR latch, not D flip-flop?** 13 devices, symmetric paths, one-transistor
  reset. Times 60 instances. Offset 0.15 ps proves it.
- **Why 15 ps, not 20?** Corner margin. Untuned SS is 18.2 ps; a 20 ps nominal
  fails SS.
- **Who sets trim codes?** Static config bits at production test, or a background
  DLL: our first future-work item.
- **Why DNL period 6?** Mapping cycles the 6 STOP taps; row-column imbalance shows
  at period $k = 6$.
- **What limits the 1 fs dead-zone number?** Simulation grid. True value is below
  it; already four orders under the LSB.
- **Offset a problem?** No. Constant per corner, 7 to 24 ps. Code offset, not
  nonlinearity. Calibrates out.
- **No temperature sweep?** TA guidance, 3 June: corners only. Corners bracket the
  speed extremes.
- **What does energy include?** DUT only. Own supply ammeter; stimulus on a
  separate rail.
