# Design notes from the 2-D Vernier paper (Vercesi/Liscidini/Castello, JSSC 2010)

> **Source:** L. Vercesi, A. Liscidini, R. Castello, "Two-Dimensions Vernier
> Time-to-Digital Converter," *IEEE J. Solid-State Circuits*, vol. 45, no. 8,
> pp. 1504–1512, Aug. 2010. (PDF at repo root: `IEEE Xplore Full-Text PDF_.pdf`.)
> This is anchor paper #2 in [`06-references.md`](06-references.md) and the
> basis of [`01-architecture.md`](01-architecture.md).
>
> **Purpose of this file:** pull out *only* what we actually need to build our
> EE4615 design — the architecture rules, the two circuit blocks, and the
> linearity/jitter lessons — and flag what to **copy**, what to **adapt** for
> 180 nm BCD / 5-bit / schematic-only, and what to **skip**. Math is LaTeX per
> this repo's `CLAUDE.md`.

---

## 0. TL;DR — what to take from this paper

| Block / idea | Take it? | For our design |
|---|---|---|
| 2-D Vernier plane + routing function | **Copy (the whole point)** | maps grid $(x,y)$ → ordered thermometer codes |
| Delay element = **2 cascaded inverters + load** | **Copy the topology** | our `delay_tau1` / `delay_tau2` |
| Time comparator = **SR latch** (not D-FF) | **Copy** | our `arbiter` cell; symmetric, low skew |
| 2 inverters per tap (non-inverting, rising-edge) | **Copy — it's mandatory with an SR latch** | both delay flavours |
| Dummy comparators at grid corners for equal loading | **Copy** | keeps every tap's load identical |
| Programmable MOM cap bank (80 caps) + DLL calibration | **Skip / simplify** | we do schematic + corners, no silicon trim → use *fixed* loading + matched cells |
| Input network (÷2, quadrature, acquire/calibrate interleave) | **Skip** | the EE4615 `TDC_in` already makes START/STOP/RESET |
| 65 nm, 7-bit/119-level, 50 Msps, DLL | **Adapt the numbers** | 180 nm BCD, 5-bit/31, Spectre corners |

---

## 1. The architecture in one page

### 1.1 Why 2-D beats linear Vernier
A linear Vernier only uses taps at the **same index** of the two lines, giving
$N$ levels from $N+N$ stages. The 2-D version uses **all** tap pairs $(x,y)$,
forming the *Vernier plane*. Differential delay at a grid point:

$$
\Delta t(x,y) = x\,\tau_1 - y\,\tau_2 .
$$

Exploring the plane instead of the diagonal multiplies the uniformly-spaced
levels by ~3 for the same lines, so for a target number of levels $N$ the
**longest delay line grows like $\sqrt{N}$ instead of $N$**. Shorter lines →
less accumulated jitter and less mismatch-induced INL (Section 3).

### 1.2 The resolution rule you must obey
The set of grid delays maps onto a uniform code only through a **routing
function** $p(x,y)$, and that function exists **iff $\tau_1$ and $\tau_2$ are
both integer multiples of the LSB $t_0$**. In the time domain:

$$
t_0 = \gcd(\tau_1,\tau_2).
$$

The clean, well-behaved family is **$\tau_1 : \tau_2 = k : (k-1)$**, for which

$$
t_0 = \tau_1 - \tau_2 ,\qquad k = \frac{\tau_1}{\tau_1-\tau_2}.
$$

> **Design rule for us:** pick $t_0$ first, then set
> $\tau_1 = k\,t_0$ and $\tau_2 = (k-1)\,t_0$.
> Our [`02-specs.md`](02-specs.md) numbers already satisfy this:
> $t_0 = 15\,\text{ps}$, $\tau_1 = 60\,\text{ps} = 4t_0$,
> $\tau_2 = 45\,\text{ps} = 3t_0$ ⇒ $k=4$, ratio $4{:}3$, $\gcd(60,45)=15$. ✓

### 1.3 Range extension trick (cheap codes)
Unlike a linear Vernier, you can **extend the range by lengthening only one
line** (line X). The paper goes from a square plane to a rectangle by adding 3
X-stages (their Fig. 4). Bound worth remembering: the **longest delay line stays
< 2× the TDC full scale** (in the paper $19\times55\,\text{ps}=1.045\,\text{ns}$
vs a 595 ps full scale), where a linear Vernier needs ≥ 2× full scale on *both*
lines.

### 1.4 Grid sizing for our 5-bit (31-code) TDC
Triangular (reachable) code count for an $N\times N$ grid is
$N(N{+}1)/2$. For 31–32 codes, $N\approx 8$ per axis (square) → 36 cells, 31
used — matches [`01-architecture.md`](01-architecture.md). With the $4{:}3$
ratio you can also use an asymmetric rectangle (more X stages, fewer Y) if it
lays out the diagonals more evenly; decide when you place the arbiter grid.

---

## 2. Circuit blocks we must hand-build

### 2.1 Time comparator = **SR latch** (paper Fig. 8)
A time comparator is a 1-bit TDC: it decides which of two rising edges arrives
first. The paper deliberately uses a **symmetric cross-coupled SR latch**, *not*
a D-flip-flop:

- **Inputs $\bar S$, $\bar R$** come from the **two delay-line taps** (one from
  line X, one from line Y). First rising edge wins → latch flips.
- Topology: a cross-coupled core of **double-sized** devices (`2*Mp`, `2*Mn`)
  with **unit output inverters** (`Mp`, `Mn`) on each side producing $Q$ and
  $\bar Q$. Perfectly mirror-symmetric.
- **Why SR over D-FF:** (1) perfect symmetry ⇒ minimal *systematic time skew*
  (skew = comparator offset = direct DNL error); (2) loads both delay lines
  identically; (3) compact — critical because a 2-D array holds *many*
  comparators.
- **Offset matching is THE spec.** Comparator offset = "time skew" = an extra
  delay between inputs ⇒ hits **DNL** directly (less so INL, since it isn't
  accumulated). Paper's Monte-Carlo input-referred offset: mean −420 fs,
  $\sigma\approx740\,\text{fs}$ (< 1 ps, for a 5 ps LSB). **Size the latch input
  devices with a Monte-Carlo `mismatch` run** until $\sigma_\text{offset}\ll
  t_0$ (aim $<t_0/5$).

- **Minimize the latch input capacitance.** The paper is explicit: "the input
  capacitance of the time comparators has to be minimized since in a 2-D
  Vernier **an entire line of comparators is connected to a single stage** of
  the delay lines. This sets the required driving capability of the delay
  element." Validated the hard way by the other EE4615 2-D group (TA session
  3 Jun 2026): under real fan-out, 45/60 ps was unreachable → longer delays,
  ~32× output drivers, 9×11 matrix.

> **Our cells:** the EE4615 library has no latch — we build it from `nmos2v`/
> `pmos2v`. The `01-architecture.md` "cross-coupled NAND or sense-amp DFF" lines
> up; prefer the **SR latch** for the symmetry argument above.

### 2.2 Delay element = **two cascaded inverters + tunable load** (paper Fig. 10)
Each tap is **two inverters in series** feeding a load capacitor at the
**internal node** (between the inverters):

- **Why two inverters, not one:** (a) the SR latch only acts on **rising
  edges**, so each tap must be **non-inverting** (even # of stages); (b) the
  second inverter **isolates** the tunable cap bank from the latch input, giving
  **sharper edges** into the comparator (better timing resolution).
- Paper sizing (65 nm, W/L in µm): inv1 = `22.4/0.06`, inv2 = `16.8/0.06`
  (equal $W_n=W_p$ there). The **tuning cap sits on the *first* inverter's
  output**; loading that node gives a clean *linear* delay-vs-code curve.
- Paper's cap bank: **40 unit cells × (2 × 5.2 fF MOM)** = 80 MOM caps, each
  switchable to ground via an n-MOS, common-centroid, "pseudo-binary" 12-wire
  control → ~1 ps tuning steps across PVT.

> **Adapt for us (no silicon, no DLL):** we don't need the 80-cap programmable
> bank. Make **$\tau_1$ and $\tau_2$ two fixed variants of the same inverter
> pair**, differing only in **load** (extra cap or a fatter/extra fan-out) or in
> $W/L$ — *keep the gate topology identical so they track over PVT* (this is the
> matching lever from `01-architecture.md` §4). A small switchable cap (a few
> codes) is still worth adding so we can re-center $t_0$ per corner in
> simulation. In 180 nm a single self-loaded inverter is much slower than 65 nm,
> so $\tau_1\approx60$ / $\tau_2\approx45\,\text{ps}$ is realistic with light
> capacitive loading at $V_{DD}=1.8\,\text{V}$.

### 2.3 Dummy comparators + thermometer ordering
- **Dummy comparators at the matrix corners** (the unused "grey-zone" cells)
  exist only to give **every delay tap the same capacitive load** — otherwise
  edge cells run faster and break linearity. Replicate this: terminate unused
  taps with dummy latch input loads.
- The flip-flop/latch outputs are **reordered by the routing function $p(x,y)$**
  — in the paper this is *literally just wiring* (Fig. 5): one comparator per
  quantization level, outputs ordered into the thermometer word. **No OR-tree.**
  *(Correction, TA session 3 Jun 2026: our earlier diagonal-OR reading of this
  was wrong — the k:(k−1) routing is bijective, so each $q_m$ is the single
  latch at $y_m=((m-1)\bmod k)+1$, $x_m=(m+(k-1)y_m)/k$. See
  `01-architecture.md` §3.)* The 31 outputs $q_1..q_{31}$ go to the testbench
  ([`../tesbench-pics/testbench-schematics-extracted.md`](../tesbench-pics/testbench-schematics-extracted.md)).

---

## 3. Noise & linearity — the lessons that set our limits

### 3.1 Jitter sets the smallest reliable $t_0$
Each stage adds uncorrelated Gaussian jitter $\sigma_\Delta$. Accumulated jitter
variance at $(x,y)$ scales with the number of stages traversed. **Rule:** keep
the **total accumulated jitter < one LSB** for < 1 LSB integral error. Because
the 2-D lines are $\sqrt{}$-shorter, accumulated jitter drops by a factor
$\propto\sqrt{N}$ vs linear — *or*, for the same power, you can spend more
current per stage to cut $\sigma_\Delta$. **For us:** prefer **fewer, stronger
delay stages** over many weak ones.

### 3.2 INL ∝ line length; DNL ∝ comparator offset
- Shorter delay lines ⇒ **~3× lower max INL** than linear (mismatch isn't
  accumulated as far).
- **INL/DNL is periodic**, with period = **number of consecutive codes on one
  diagonal** (= $k$-ish; 11 in the paper). Expect a repeating ripple, not random.
- **DNL spikes when consecutive codes jump to a different diagonal** — these are
  the worst-DNL points; watch them in our sweep.
- **Mismatch between supposedly-identical $\tau_1$ stages (or $\tau_2$ stages)**
  is the dominant INL source ⇒ use **identical cells** throughout and size with
  margin (our `mc_lib`/`mismatch_lib` Monte-Carlo).

### 3.3 A real-world warning the paper gives for free
Their measured INL had a big non-periodic **bump that was NOT the architecture**
— it came from **input-network crosstalk** pulling the edges when START/STOP got
very close. **Lesson for us:** the analog front of the bench matters. When two
edges are within a few ps, coupling on shared nets distorts the ramp. Keep the
`START`/`STOP` paths and the grid's row/column wiring well separated (the
"crosstalk between rows and columns" risk already in `04-implementation-plan.md`).

---

## 4. Calibration / DLL — what they do, and why we can skip it
The prototype keeps $\tau_1/\tau_2 = k/(k-1)$ locked with a **DLL**: feed both
lines the same signal, use the latch at position (10,11) to measure the
$10\tau_X$ vs $11\tau_Y$ error, filter it with an IIR, and digitally trim line
Y's caps. The input network **interleaves acquire/calibrate** every cycle
(100 MHz ÷2 → quadrature), which is why it burns 2× power.

**We don't need this** for an EE4615 schematic + corner study:
- No silicon drift to track — Spectre gives us the exact corner.
- Instead we **size for the worst corner** so $\tau_2$ stays $> 0$ and
  $t_0<20\,\text{ps}$ across $\{TT,SS,FF,SF,FS\}\times\{-40,27,150\}^\circ$C.
- A **few** switchable cap codes (not 80) let us re-center $t_0$ per corner in
  simulation if needed — that's the honest, low-effort analogue of their DLL.
- Mention the DLL in the report as the path to a *robust silicon* version, and
  cite the calibration-covers-only-half-the-line caveat as why their high-code
  INL grew.

---

## 5. Paper numbers vs our target (quick reference)

| Quantity | Paper (Vercesi 2010) | Our EE4615 target |
|---|---|---|
| Technology | 65 nm CMOS | **TSMC 180 nm BCD** (`nmos2v`/`pmos2v`) |
| $V_{DD}$ | 1.2 V (meas.) | **1.8 V** nominal |
| Resolution $t_0$ | 4.8–5 ps | **< 20 ps** (target ≈ 15 ps) |
| Bits / codes | 7-bit / 119 levels | **5-bit / 31 (thermometer)** |
| $\tau_1$ (line X) | 55 ps | ≈ 60 ps ($=4t_0$) |
| $\tau_2$ (line Y) | 50 ps | ≈ 45 ps ($=3t_0$) |
| Ratio $k:(k-1)$ | 11 : 10 | **4 : 3** |
| Stages | 19 (X), 11 (Y) | $N_Y=k$, $N_X$ from routing table ($k{=}4$ → 4×~11; other group: 9×11) |
| Longest line | 1.045 ns (< 2× FS) | keep < 2× full scale |
| Comparator | SR latch, $\sigma_\text{off}\approx0.74$ ps | SR latch, $\sigma_\text{off}\ll t_0$ |
| Min inverter delay | 20 ps (worst PVT) | larger in 180 nm → Vernier still needed |
| Calibration | DLL + 80-cap bank | none (corner-sized) + few sim trims |
| FoM | 0.28 pJ/step | compute $\mathrm{FoM}=P/t_0$ per `02-specs.md` |

---

## 6. Where this plugs into our plan
Mapping to [`04-implementation-plan.md`](04-implementation-plan.md), built inside
the empty **`td`** core (interface `RESET/START/STOP/VDD/GND → q1..q32`, see the
testbench map):

1. **Phase 1 cells** — build, in order the paper recommends:
   `arbiter` = **SR latch** *first* (its offset/jitter/input-cap set
   everything), then `delay_tau1`/`delay_tau2` = **inverter-pair +
   fixed/lightly-switched load + strong output driver**, sized to
   $\tau_1{=}k\,t_0$, $\tau_2{=}(k{-}1)\,t_0$ **under replica column load**
   ($k{=}4$ if reachable, else larger).
2. **Phase 2 (1-D row)** — verify LSB $= \tau_1-\tau_2$ and that the SR latch
   resolves down near $t_0$ (characterise the **metastable "dead zone"**).
3. **Phase 3 (2-D grid)** — add **dummy latch-input loads** so every tap sees
   equal fan-out; route each latch output **directly** to its $q_m$ pin per the
   bijective table (no OR-tree); keep row/column nets apart (crosstalk).
4. **Phase 4 (corners)** — confirm $\tau_2>0$ and $t_0<20$ ps in **FF / −40 °C**
   (the corner most likely to collapse $\tau_1-\tau_2$); resize with headroom.
5. **Report** — use the paper's INL-periodicity and the "shorter-lines ⇒
   lower INL/jitter" arguments to *explain* our DNL/INL shapes, and the
   input-network-crosstalk story to interpret any non-periodic INL bump.

## 7. Open questions this paper raises for us
- ~~Square 8×8 vs asymmetric rectangle?~~ **Resolved (TA session 3 Jun 2026):**
  the bijective routing fixes the shape — $N_Y=k$, $N_X$ from the table
  ($k{=}4$ → 4×~11; $k{=}9$ → 9×11). The remaining choice is **$k$ itself**,
  driven by the smallest $\tau$ the loaded delay element can hit.
- **How many switchable cap codes** (if any) do we expose for per-corner
  re-centering, given we can't run a DLL in a pure schematic submission?
- **Do we count TDC_in/TDC_out inverters in $\sum W$?** (already a TA question in
  `02-specs.md` — the paper's area is dominated by digital, so scope matters.)
