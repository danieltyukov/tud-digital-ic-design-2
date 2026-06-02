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

Trade summary for a 5-bit (32-code) TDC:

| Property                          | 1-D Vernier    | 2-D Vernier                  |
|-----------------------------------|----------------|------------------------------|
| Δt LSB                            | $\tau_1 - \tau_2$ | $\tau_1 - \tau_2$         |
| Stages for range $R = 32\,t_0$    | $N = 32$       | $N \approx \sqrt{2\cdot 32} \approx 8$ per axis |
| $\sum$ delay cells                | $64\;(32+32)$  | $16\;(8+8)$ ⇒ $\tfrac{1}{4}$ the cells |
| $\sum$ arbiter D-FFs              | $32$           | $32$ (one per grid cell used) |
| Bottleneck                        | Cell count     | DFF count + routing fan-out  |

So the 2-D version saves $\sim 4\times$ in delay cells, at the cost of
more DFFs and more routing.

## 2. Block diagram

```
              ┌──────────────┐
   START ─►──┤ τ₁ stage 1   ├──► τ₁ stage 2 ─► ... ─► τ₁ stage N
              └─────┬────────┘            ↓                ↓
                    │     ┌──────────┐   ┌──────────┐
                    └────►│ DFF(1,0) │   │ DFF(2,0) │ ...
                          └─────▲────┘   └─────▲────┘
                                │              │
   STOP  ─►── τ₂ stage 1 ──► τ₂ stage 2 ─► ... ─► τ₂ stage M
              └─────┬────────┘
                    │     ┌──────────┐
                    └────►│ DFF(0,1) │ ...
                          └──────────┘
```

Each arbiter DFF samples the Start-row signal with the Stop-column signal as
clock. The output of cell $(i,j)$ latches to $1$ iff Start has propagated
past stage $i$ before Stop reaches stage $j$ — equivalently, when

$$
\Delta t > i\,\tau_1 - j\,\tau_2.
$$

## 3. Mapping the 2-D code to a thermometer / binary output

The triangular set of DFFs ($j \le i$) gives a 2-D "staircase" code. To
match the EE4615 testbench (which expects a 5-bit thermometer $Q_1..Q_{31}$
or 5-bit binary $Q_1..Q_5$), we map the active grid cells to a **1-D
thermometer output** along the diagonal levels (each diagonal corresponds
to one $\Delta t$ quantum):

- Define $t_0 = \tau_1 - \tau_2$.
- Group all grid cells $(i,j)$ with $i - j = k$ into "thermometer level $k$".
- $Q_k = \bigvee_{i-j = k}\, \text{DFF}_{i,j}$ — the OR over all DFFs in level $k$.

This OR-tree is the only block that grows wide; everything else (delay
cells, DFFs) is local and small.

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
| Inverter ($\times 1, \times 2, \times 3, \times 5, \times 20$) | Delay-stage building block; also in TB load |
| Buffered delay element ($\tau_1$ and $\tau_2$ flavours) | The Vernier delays themselves |
| Arbiter D-FF (cross-coupled NAND or sense-amp) | Each grid cell        |
| OR / NOR tree | Level decoder $Q_k = \bigvee_{\text{diag}}$              |
| Reset gating | Async reset on every DFF, driven from 40-ps RESET pulse   |

All must be hand-built — Rabaey Ch. 6 styles are allowed (complementary
CMOS, pass-transistor, dynamic). No `analogLib` or `tsmc18` digital cells.

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
4. **OR-tree skew** — different diagonal levels see different OR depths.
   Equalise either by buffering or by a balanced reduction tree.
