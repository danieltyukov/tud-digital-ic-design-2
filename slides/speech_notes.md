# Speech notes — EE4615 final presentation, Group 22

**Deck:** `EE4615_Group22_2D_Vernier_TDC.pptx` (16 slides)
**Format:** 10 minutes talk + 5 minutes Q&A. We switch speaker every slide, so each of
us presents architecture material *and* results material. Target pace is about 40
seconds per content slide. Times below are cumulative.

| Slide | Speaker | Topic | Time |
|---|---|---|---|
| 1 | Daniel | Title, team intro | 0:00 |
| 2 | Daniel | The brief | 0:20 |
| 3 | Joris | Why 2-D Vernier | 1:00 |
| 4 | Daniel | Architecture, $k=6$ | 1:40 |
| 5 | Joris | Delay stage | 2:20 |
| 6 | Daniel | SR-latch arbiter | 3:00 |
| 7 | Joris | The loading pivot | 3:40 |
| 8 | Daniel | Cadence build + testbench | 4:20 |
| 9 | Joris | Staircase per corner | 5:00 |
| 10 | Daniel | DNL / INL | 5:40 |
| 11 | Joris | Calibration | 6:20 |
| 12 | Joris | Metastability | 7:00 |
| 13 | Daniel | 1-D vs 2-D measured | 7:40 |
| 14 | Joris | Scorecard | 8:20 |
| 15 | Daniel | Conclusions | 9:00 |
| 16 | Joris | Thank you | 9:40 |

---

## Slide 1 — Title *(Daniel, ~20 s)*

Good morning everyone. We are Group 22, I am Daniel and this is Joris. For our
EE4615 project we designed a two-dimensional Vernier time-to-digital converter in
TSMC 180 nm, with a 15 picosecond resolution and a 5-bit thermometer output. The
schematic you see behind the title is our actual core. We built and analyzed
everything together, so we will be switching speakers every slide.

## Slide 2 — The brief *(Daniel, ~40 s)*

The task is to measure the time between a START edge and a STOP edge and turn it
into a 5-bit thermometer code. The hard requirements: resolution better than 20
picoseconds, the full 32-code range, and the design has to survive all five process
corners. And the rules are strict: 180 nanometer BCD at 1.8 volts, no standard
cells at all, every gate built by hand, and verification by Spectre simulation
only. Beyond passing, we optimize the trade-off between linearity, energy per
conversion, area counted as total transistor width, and the figure of merit, which
is energy per conversion step. We chose the two-dimensional Vernier because it is
the structure that breaks the usual link between resolution and range. Joris will
explain how.

## Slide 3 — Why Vernier, and why 2-D *(Joris, ~40 s)*

In a Vernier TDC the START edge travels through slow stages with delay $\tau_1$
and the STOP edge chases it through faster stages $\tau_2$. Every stage, STOP
gains $t_0 = \tau_1 - \tau_2$ on START. That difference is our LSB, and it can be
far below a single gate delay. The catch in one dimension: one stage pair per
code, so 5 bits cost 32 stages in each line, and latency grows the same way. The
2-D idea is to compare START tap $i$ against STOP tap $j$. Each pair measures
$i\,\tau_1 - j\,\tau_2$, so a small grid of combinations covers the whole range.
For us that means 31 codes from only 10 plus 6 delay stages: a quarter of the
delay cells and almost four times lower latency for the same resolution.

## Slide 4 — Architecture *(Daniel, ~40 s)*

We locked the design at $k = 6$, meaning $\tau_1 = 90$ and $\tau_2 = 75$
picoseconds, ten and six stages. That gives $t_0 = 15$ picoseconds, five below the
spec limit. The key property of this operating point is the routing: the mapping
from thermometer level to grid cell is bijective, the formula is on the slide.
Every level is exactly one SR latch routed straight out. There is no OR tree, so
there is no skew from combining logic to corrupt the code. We then pad the 31
active latches with 29 dummies to a symmetric ten by ten array, so every delay tap
sees identical fan-out. Buffer trees distribute START, STOP, and the 40
picosecond RESET pulse.

## Slide 5 — Delay stage *(Joris, ~40 s)*

This cell is where the resolution is made. Our first attempt used the textbook
fan-out-of-four sizing, and that pinned the minimum stage delay at 97 picoseconds,
which made the targets unreachable. Switching to a fan-out-of-one inverter pair
dropped the internal node capacitance and opened a tuning window from 74 to 147
picoseconds. Both lines use identical active devices. The six-to-five delay ratio
comes purely from loading, which is what makes $\tau_1$ and $\tau_2$ track each
other across corners, and tracking is everything when your LSB is a difference.
On the internal node sits a fixed MOSCAP for the nominal delay plus three
transmission-gate switched banks. Those give us up to 48 picoseconds of
calibration authority, which we will use later.

## Slide 6 — Arbiter *(Daniel, ~40 s)*

The arbiter decides which edge arrived first, and we built it as a cross-coupled
NAND SR latch, 13 transistors, every device 440 over 180 nanometers. Both NAND
outputs idle high, and the first rising input wins the race, so the latch directly
records the comparison. Equal NMOS and PMOS widths keep the set and reset paths
balanced, and that symmetry is why the arbitration offset ends up at the
femtosecond level, as you will see in the measurements. A single NMOS clears the
latch during the 40 picosecond RESET pulse. We deliberately chose this over a D
flip-flop: with 60 instances in the grid, a smaller, symmetric cell with one-transistor
reset wins on every metric we care about.

## Slide 7 — The loading pivot *(Joris, ~40 s)*

This slide is the most important design lesson of the project. A delay tap in the
grid does not drive a test load, it drives a full row or column of latches plus
the next delay stage, roughly a 20 times equivalent load. We learned this the hard
way: sizing against an idealized load predicted a 16.6 picosecond LSB, and the
same hardware measured 28.6. Almost a factor of two, purely from loading. So we
re-characterized every stage under a replica of the real load, and we equalized
all taps with the dummy latches you see here. That is also what killed our
original $k = 4$ operating point at 60 and 45 picoseconds and re-locked the design
at $k = 6$. In a Vernier grid, loading is architecture, not a layout detail.

## Slide 8 — Build and testbench *(Daniel, ~40 s)*

Here is the core as built: 18 delay stages, 60 latches, 1120 devices, 1306
micrometers of total transistor width, every cell hand-made in our vernier2d
library. Verification runs through the course TB_TDC harness. One detail we want
to highlight: the DUT sits on its own supply behind a series ammeter, while the
stimulus buffers run from a separate rail, so the energy numbers you are about to
see contain only the converter itself. The whole campaign is automated in OCEAN:
it steps the input delay through all 32 codes, per corner, and extracts LSB, DNL,
INL, energy, and pass or fail without manual work. Joris takes it from here with
the results.

## Slide 9 — Staircase *(Joris, ~40 s)*

This is the measured transfer curve in all five corners, with one fixed trim
code, no per-corner tweaking. Every corner gives a clean 31-step staircase, no
step missing anywhere. The LSB ranges from 13.1 picoseconds in the fast-fast
corner to 18.2 in slow-slow, so even the worst corner clears the 20 picosecond
spec. You can also see the curves shift horizontally: that is a static offset of
at most about one and a half LSB, and since it is constant per corner it
calibrates out. So the headline: the spec is met in every corner before we apply
any calibration at all.

## Slide 10 — Linearity *(Daniel, ~40 s)*

Linearity confirms it. Worst-case DNL is 0.90 LSB in the slow-slow corner, well
clear of the minus one LSB limit where codes start disappearing, so there are no
missing codes in any corner. Worst INL is 1.04 LSB, again slow-slow, and every
other corner stays below 0.8. One detail worth pointing out: the DNL pattern
repeats every six codes. That is the residual imbalance between rows and columns
of the grid, and the period is exactly our $k$. It is the known fingerprint of a
2-D Vernier, so seeing it tells us the converter behaves exactly as the theory
says it should.

## Slide 11 — Calibration *(Joris, ~40 s)*

Now we switch the MOSCAP banks on. The three banks per stage act as static
configuration bits, set once per corner, like a fuse setting after production
test. On the left, gray is untuned and blue is calibrated: the LSB spread across
corners collapses from 5.1 picoseconds to 0.85, six times tighter, with every
corner re-centered between 15.0 and 15.9 picoseconds. Worst INL improves to 0.74
LSB, and the figure of merit stays around half a picojoule per step. The right
plot shows why this works: the achieved $t_0$ moves monotonically with the engaged
capacitor imbalance, and every corner crosses the 15 picosecond target line, so a
valid code always exists.

## Slide 12 — Metastability *(Joris, ~40 s)*

A Vernier TDC is only as good as its arbiter, so we characterized ours down to
half a femtosecond of input overdrive, 49 simulations in total. Three numbers
matter. The arbitration offset is plus 0.15 picoseconds, about one percent of an
LSB, so the race is effectively fair. The dead zone, where the decision is
ambiguous, is below one femtosecond, four orders of magnitude under our LSB. And
the regeneration time constant is 24.1 picoseconds, with the worst observed
decision time at 348 picoseconds, comfortably inside the conversion window. The
conclusion: metastability does not limit this design, the LSB does, which is
exactly what you want.

## Slide 13 — 1-D vs 2-D, measured *(Daniel, ~40 s)*

We did not just claim the 2-D structure is better, we measured it. We rebuilt a
one-dimensional Vernier row from exactly the same delay cells and latches. With
raw, unequalized tap loading it delivers a 28.6 picosecond LSB against our 15.35,
worse DNL, and double the transistor width per code. Energy per code is
comparable, so the grid does not cost us efficiency. Extrapolating that row to
the full 31 codes needs 3.4 times the delay stages, 1.9 times the area, and 3.3
nanoseconds of full-scale latency against our 0.9. Same cells, same process: the
two-dimensional arrangement with equalized loading is simply the better converter.

## Slide 14 — Scorecard *(Joris, ~40 s)*

Putting it all together against the course requirements. Five output bits,
check. Resolution: 15.0 to 15.9 picoseconds calibrated, against a 20 picosecond
spec. Corner robustness: five out of five corners pass. DNL worst case 0.89, so
no missing codes; INL 0.74 calibrated. And the reported metrics: 10.7 to 13
picojoules per conversion, a figure of merit around 0.5 picojoule per step, 1306
micrometers of transistor width, and an ENOB between 4.4 and 4.6 bits. Every hard
requirement is met with margin, and everything on this table comes from the
Spectre corner sweeps with the official course testbench.

## Slide 15 — Conclusions *(Daniel, ~40 s)*

To conclude. We built a 15 picosecond, 5-bit, two-dimensional Vernier TDC in 180
nanometers that meets every course requirement in all five corners. Two ideas
carried the design: characterize the delay cells under the real grid load instead
of an idealized one, and equalize every tap with dummy latches. And calibration
turned out to be cheap: three small MOSCAP banks per stage buy a six times tighter
LSB spread. Given more time we would add DLL-based background calibration, a
voltage-to-time front end to use this TDC as an ADC quantizer, and a layout with
extracted re-simulation. And to be clear, all of this was joint work between the
two of us, end to end.

## Slide 16 — Thank you *(Joris, ~15 s)*

That was our two-dimensional Vernier TDC. Thank you for your attention, we are
happy to take your questions.

---

## Q&A preparation (5 minutes, either of us answers)

- **Why an SR latch and not a D flip-flop arbiter?** Fewer devices per cell (13),
  symmetric S and R paths for low offset, and one-transistor async reset. With 60
  instances, cell economy dominates. Measured offset 0.15 ps backs the choice.
- **Why target $t_0 = 15$ ps and not closer to 20?** Margin for corner spread:
  untuned SS sits at 18.2 ps. With a 20 ps nominal target, SS would fail.
- **Who sets the trim codes in a real chip?** They are static configuration bits,
  set at production test or by a DLL running in the background; that DLL is our
  first future-work item.
- **Why does DNL repeat every 6 codes?** The level-to-cell mapping cycles through
  the 6 STOP taps with period $k = 6$, so any residual row-versus-column delay
  imbalance shows up with that period. It is the standard 2-D Vernier signature.
- **What limits the dead zone measurement at 1 fs?** Our simulation grid: the
  finest overdrive step we ran. The true ambiguity window is bounded below that,
  already four orders under the LSB.
- **Is the offset a problem?** No. It is constant per corner (7 to 24 ps), so it
  is a code offset, not a linearity error, and standard offset calibration removes
  it.
- **Why no temperature sweep?** Following the TA guidance of 3 June, validation is
  corners-only; the corner set already brackets the device speed extremes.
- **What does the energy number include?** Only the DUT: the core sits behind its
  own supply ammeter and the stimulus buffers run from a separate rail.
