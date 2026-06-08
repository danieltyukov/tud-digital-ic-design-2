# 2-D Vernier TDC — Architecture

> Source anchors: Liscidini *et al.* CICC 2009; Vercesi *et al.* JSSC Aug 2010.
> Lecture 2 of EE4615 (Digital IC Design II), slides 28–31.

## 1. Why 2-D over 1-D Vernier

A **1-D Vernier TDC** uses two delay chains:
- Start path with per-stage delay $\tau_1$ (slower).
- Stop path with per-stage delay $\tau_2$ (faster, $\tau_2 < \tau_1$).

The effective LSB is

$$
t_0 = \tau_1 - \tau_2
$$

which can be much smaller than a single inverter delay. The catch is that
the **range** grows as $N\,(\tau_1 - \tau_2)$, so for fine resolution you
either eat huge area in cells or you accept a short range.

The **2-D Vernier** breaks that trade-off by laying out a **grid** of
$(\text{Start-delay}, \text{Stop-delay})$ combinations. Each $(i,j)$ cell on
the grid maps to a unique time difference

$$
\Delta t_{i,j} = i\,\tau_1 - j\,\tau_2.
$$

Only the **triangular region** $\{(i,j) : j \le i\}$ is physically reachable
(Stop can't arrive before Start), but that triangle already covers
$\sim \tfrac{1}{2} N^2$ unique codes from $N + N$ delay stages.

Trade summary for our 5-bit (32-code) TDC, locked at $k=6$:

| Property                          | 1-D Vernier    | 2-D Vernier (our $k{=}6$)    |
|-----------------------------------|----------------|------------------------------|
| Δt LSB                            | $\tau_1 - \tau_2$ | $\tau_1 - \tau_2 = 15\,\text{ps}$ |
| Stages for range $R = 32\,t_0$    | $N = 32$       | $N_X{=}10$ (START) $+\;N_Y{=}6$ (STOP) |
| $\sum$ delay cells                | $64\;(32+32)$  | $16\;(10+6)$ ⇒ $\tfrac{1}{4}$ the cells |
| $\sum$ arbiters                   | $32$           | $31$ SR latches (one per level $m$) |
| Bottleneck                        | Cell count     | Latch count + routing fan-out |

So the 2-D version saves $\sim 4\times$ in delay cells, at the cost of
more arbiters and more routing.

## 2. Block diagram

```
              ┌──────────────┐
   START ─►──┤ τ₁ stage 1   ├──► τ₁ stage 2 ─► ... ─► τ₁ stage 10
              └─────┬────────┘            ↓                ↓
                    │     ┌──────────┐   ┌──────────┐
                    └────►│ SRL(1,1) │   │ SRL(2,1) │ ...
                          └─────▲────┘   └─────▲────┘
                                │              │
   STOP  ─►── τ₂ stage 1 ──► τ₂ stage 2 ─► ... ─► τ₂ stage 6
              └─────┬────────┘
                    │     ┌──────────┐
                    └────►│ SRL(1,2) │ ...
                          └──────────┘
```

Each arbiter is an **SR latch** that resolves which edge arrived first: the
Start tap drives one input, the Stop tap the other. The latch at cell $(i,j)$
sets to $1$ iff Start has propagated past stage $i$ before Stop reaches stage
$j$ — equivalently, when

$$
\Delta t > i\,\tau_1 - j\,\tau_2.
$$

## 3. Mapping the 2-D code to a thermometer / binary output

The triangular set of arbiter latches ($j \le i$) gives a 2-D "staircase" code. To
match the EE4615 testbench (which expects a 5-bit thermometer $Q_1..Q_{31}$
or 5-bit binary $Q_1..Q_5$), we map the active grid cells to a **1-D
thermometer output** along the diagonal levels (each diagonal corresponds
to one $\Delta t$ quantum):

- Define $t_0 = \tau_1 - \tau_2$ and pick $\tau_1 = k\,t_0$, $\tau_2 = (k-1)\,t_0$.
- In this family the routing function is **bijective** (Vercesi eqs. (3)–(4)):
  level $m$ maps to exactly one cell
  $$y_m = \big((m-1) \bmod k\big) + 1, \qquad x_m = \frac{m + (k-1)\,y_m}{k}.$$
- $Q_m = \text{SR-latch}_{x_m,y_m}$ **directly — no OR-tree.** Each thermometer
  bit is one arbiter output routed straight out (the paper's Fig. 5 does exactly
  this: the latch outputs are *ordered*, not combined).

> *Correction (TA session, 3 Jun 2026):* an earlier revision of this file
> grouped diagonal cells with an OR-tree ($Q_k=\bigvee_{i-j=k}$). That
> construction is unnecessary — the bijective routing above replaces it, which
> also removes the OR-tree-skew problem entirely. Line lengths follow from $k$:
> $N_Y = k$, $N_X = \max_m x_m$. **Locked at $k=6$:** $N_Y=6$ (STOP/$\tau_2$),
> $N_X=10$ (START/$\tau_1$) ⇒ a **10×6 logical** grid (10×10 physical after
> dummy-padding to equalise per-tap fan-out).

## 4. What sets the resolution, and what doesn't

- $\tau_1$ and $\tau_2$ individually are *not* what matters — only the
  difference $\tau_1 - \tau_2$. So in design we focus on **matching**:
  $\tau_1$ and $\tau_2$ must track each other across PVT so $\tau_1 - \tau_2$
  stays close to its nominal LSB.
- **Mismatch** between supposedly-identical $\tau_1$ stages (and likewise
  $\tau_2$) causes DNL spikes. Two big mitigation levers: layout-like
  sizing (we don't draw layout, but we can size with margins), and using
  identical cells throughout the chain.
- **Arbiter setup/hold** sets the smallest resolvable $\Delta t$. A
  latch-based arbiter with positive feedback meta-stabilises at very
  small $\Delta t$ — that's the bottom-end of what the TDC can resolve
  before resolution collapses.

## 5. Cells we will need (no standard cells allowed)

| Cell           | Purpose                                                   |
|----------------|-----------------------------------------------------------|
| Inverter (`Inv_varx`, FO=1 pair) | Delay-stage building block; $\text{Inv}_\text{in}{=}2\times$, $\text{Inv}_\text{out}{=}2\times$ |
| Delay element `delay_tau1` / `delay_tau2` | The Vernier delays (90 / 75 ps) + transmission-gate–switched MOSCAP tuning banks |
| Arbiter **SR latch** (`srlatch`: cross-coupled NAND + async RESET) | One per used grid cell |
| Output routing | One latch per level, routed straight to $Q_m$ (no OR-tree — see §3) |
| Reset gating | Async reset on every latch, driven from 40-ps RESET pulse |

All must be hand-built — the brief's **Chapter 4** logic styles are allowed
(complementary CMOS, pass-transistor, dynamic). No `analogLib` or `tsmc18`
digital std-cells. The reused `Testbench` inverters (`Inv`, `Inv_2x`,
`Inv_3x`, `Inv_5x`) are themselves hand-built CMOS, so they are permitted.

## 6. Design pitfalls (worth pre-registering)

1. **$\tau_1 - \tau_2$ vanishes in fast corners.** Pick $\tau_2$ such that
   even at FF / $-40^\circ\text{C}$ the difference stays positive. Use the
   same gate topology for both chains so they scale together — differ only
   in capacitive loading or $W/L$.
2. **Arbiter metastability** at small $\Delta t$ — characterise where the
   gain collapses and document it as the TDC's "dead zone".
3. **Cross-talk between rows and columns** — long wires through the grid
   couple. The 2-D layout (even at schematic level) needs careful net
   ordering.
4. **Per-tap fan-out loading** *(resolved — drove the $k{=}6$ pivot)* — every
   delay tap drives all the latches on its row/column **plus the next delay
   stage**. Sizing $\tau_1/\tau_2$ without that replica load gives a fictitious
   LSB. Characterising the cell under the real $\approx 20\times$ load
   (10 latches + 1 downstream stage) is what moved us off $k{=}4$/60–45 ps to
   the locked $k{=}6$/90–75 ps, 10×6 grid — see `delay_progress.md`. Open
   sub-risk: in **FF** the slow line can't be padded back up to 90 ps even with
   all MOSCAPs in, so $t_0$ contracts — needs extra cap range.
