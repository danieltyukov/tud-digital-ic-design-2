# Build & test runbook — 2-D Vernier TDC (fast path)

> **Goal:** the shortest correct path from empty `td` to a corner-verified,
> energy-characterised 5-bit 2-D Vernier TDC — reusing everything the course
> already provides and building only the 3 cells that don't exist yet.
>
> **Decisions locked** (the rest of this doc assumes them):
> 1. Core lives in our own library **`tdc_2d_vernier` → cell `tdc_core`**, with
>    pins identical to `td`; we **re-point the `TDC` wrapper's `I13` instance**
>    from `td` to `tdc_core`. The wrapper (supply ammeters `/I1/VDD`, `q32`
>    termination) and the whole provided testbench stay untouched.
> 2. **Reuse the Testbench inverters** (`Inv`,`Inv_2x`,`Inv_3x`,`Inv_5x`) — never
>    redraw them.
>
> Companion docs: architecture [`01`](01-architecture.md), specs [`02`](02-specs.md),
> testbench [`03`](03-testbench.md), paper notes [`07`](07-paper-2d-vernier-design-notes.md),
> cell map [`../tesbench-pics/testbench-schematics-extracted.md`](../tesbench-pics/testbench-schematics-extracted.md).

---

## What we build vs. what we reuse (the whole bill of materials)

| Item | Source | Note |
|---|---|---|
| `Inv`,`Inv_2x`,`Inv_3x`,`Inv_5x` | **reuse** `Testbench` | delay-tap + buffer inverters |
| `TB_TDC`, `TDC_in`, `TDC_out`, `POWER`, `TDC` wrapper | **reuse** `Testbench` | full test harness — we don't build a testbench |
| OCEAN scripts + `run-testbench.sh` | **reuse** | DNL/INL/energy sweep already written |
| `nand2`, `nor2` | **build** | latch + OR-tree primitives |
| `srlatch` (arbiter, +RESET) | **build** | the keystone — design first |
| `delay_tau1`, `delay_tau2` | **build** | 2× `Inv` + load; only the load differs |
| `or_tree` | **build** | per-diagonal OR reduction |
| `tdc_core` | **build** | delay lines + arbiter grid + OR-tree |

**Only 3 conceptually-new things:** the arbiter, the delay element, and the
grid+OR-tree assembly. Everything else is reuse.

---

## Phase 0 — environment & library (≈ 30 min, once)

1. `./first-time-setup.sh` (once) → uploads `Testbench`, makes `~/simulation`,
   `~/tmp`, `~/sims`. Then `./launch-cadence.sh` for each session.
2. In Virtuoso: **File → New → Library** `tdc_2d_vernier`, attach to tech
   `tsmc18` (Reference existing technology). Then on the server append it to
   `cds.lib`: `./register-library.sh tdc_2d_vernier`.
3. Confirm you can instantiate `Testbench/Inv` into a scratch schematic in
   `tdc_2d_vernier` (cross-library instancing works) and that ADE sees
   `nmos2v`/`pmos2v` from `tsmc18`.

### Where every symbol comes from (no need to draw these)

| Library | Symbols we instantiate | Allowed in… |
|---|---|---|
| `tsmc18` | `nmos2v`, `pmos2v` | every custom cell |
| `basic` | pins (`ipin`/`opin`/`iopin`), wires, `noConn` | every cell |
| `Testbench` | **reuse** `Inv`,`Inv_2x`,`Inv_3x`,`Inv_5x`; harness `TB_TDC`/`TDC_in`/`TDC_out`/`POWER`/`TDC`; (`txg`,`Mux` if useful) | core (inverters) + test |
| `analogLib` | `vpulse`,`vpwl`,`vdc`,`idc`,`gnd`,`cap`, ports | **scratch testbenches ONLY — not in `tdc_core`** |
| `ahdlLib(_updated)` | (optional) Verilog-A ideal delay/comparator | a behavioral 2-D model to pre-check the routing table |

> **Core purity rule** ([`05`](05-deliverables.md)): no `analogLib` inside `tdc_core`. The
> `delay_tau*` load is a **`tsmc18` MOS-cap or fan-out**, never an `analogLib/cap`.
>
> Other libs on the server (`ee4610`, `assignment*_et4382`, `Tutorial*`,
> `SCPC2025`, `SMPC*`) are unrelated coursework — *but* may already hold a
> hand-built latch / NAND / NOR worth reusing; check before building from
> scratch in Phase 1.

**Sign-off:** new cell in `tdc_2d_vernier` simulates a reused `Inv` in ADE
(transient, $V_{DD}=1.8$) and swings rail-to-rail.

---

## Phase 1 — the arbiter `srlatch` (keystone — build FIRST)

The paper designs the time comparator before anything else, because its offset
and jitter set the floor for the whole TDC ([`07`](07-paper-2d-vernier-design-notes.md) §2.1).

**Build**
- `nand2`, `nor2` — **transistor-level** cells from `nmos2v`/`pmos2v` (NOT made
  from inverters; a gate is its own 4-T topology). Tip: copy a `Testbench/Inv`
  schematic as a *drawing canvas* (it has the `VDD`/`GND` pins + one P + one N),
  then add the 2nd transistor and re-wire. All `L=180\,\text{n}`:
  - `nand2`: PMOS ×2 **parallel** ($W_p=440$ n each); NMOS ×2 **series**
    ($W_n=440$ n each — 2× to offset the stack).
  - `nor2`: PMOS ×2 **series** ($W_p=880$ n each — 2×); NMOS ×2 **parallel**
    ($W_n=220$ n each).
  - *(Fast first cut: unit 440/220 everywhere works, just slightly skewed.)*
  - **Where each goes:** `nand2` → the `srlatch` (comparator is NAND-only).
    `nor2` → the **diagonal OR-tree** only (`q_k = OR` of a diagonal = `nor2`+inv).
    *(NOR isn't strictly required — `OR = NAND(\bar a,\bar b)` by De Morgan, so a
    NAND-only tree is possible — but `nor2`+inv keeps the OR-tree tidy with
    fewer stray inversions to skew-match across diagonals.)*
- `srlatch` = two cross-coupled `nand2` (symmetric mutual-exclusion / SR latch),
  inputs `S` = Start-tap, `R` = Stop-tap (active-high rising edges), outputs
  `Q`,`Qb`. Add an **async `RESET`** that forces `Q=0` (an `nmos2v` pulldown on
  the Q node gated by RESET, or a 3rd input on the gates). Keep the two halves
  mirror-identical so both delay lines see the same input cap (zero systematic
  skew — the reason for SR over D-FF).
- Pins: `S`, `R`, `RESET`, `Q`, `Qb`, `VDD`, `GND`. Make the symbol.

**Test** (scratch testbench in `tdc_2d_vernier`, two `vpulse` sources for S/R)
1. **Function:** S rises 10 ps before R → `Q=1`; R first → `Q=0`; RESET clears.
2. **Dead-zone / metastability:** sweep the S–R skew from +20 ps down through 0;
   find the smallest |Δt| where Q still resolves to a clean rail within the bit
   period. Record this as the **dead zone** (a required deliverable, [`02`](02-specs.md) §6).
3. **Offset (the DNL driver):** Monte-Carlo `mismatch` run (≥200 pts), S and R
   tied to the same edge, measure the input-referred time offset histogram.
   Target $\sigma_\text{offset}\ll t_0$ (aim $< 3\,\text{ps}$ for a 15 ps LSB);
   up-size the cross-coupled devices until met.

**Sign-off:** correct arbitration, dead zone measured, $\sigma_\text{offset}<3$ ps in TT mismatch.

---

## Phase 2 — the two delay elements (`delay_tau1`, `delay_tau2`)

Both are the **same cell topology** — two reused `Inv` in series (non-inverting;
mandatory because the SR latch acts on rising edges, [`07`](07-paper-2d-vernier-design-notes.md) §2.2).
They differ **only in the load** on the internal node, so they track over PVT.

**Build**
- `delay_tau1`: `in → Inv → (node A) → Inv → out`, plus a small load on node A.
  Realize the load **without analogLib**: a MOS-cap (`nmos2v` with S/D/B tied to
  GND, gate on node A) or extra dummy `Inv` inputs hung on node A. Size for
  $\tau_1\approx60\,\text{ps}$.
- `delay_tau2`: identical, lighter load → $\tau_2\approx45\,\text{ps}$.
- Add **2–3 switchable MOS-caps** (each an `nmos2v` cap in series with an
  `nmos2v` switch) on node A so you can re-center $t_0$ per corner in simulation
  — this is the cheap stand-in for the paper's DLL (we do **not** build a DLL).
- Pins: `in`,`out`,`VDD`,`GND` (+ `trim<0:2>` if switchable). Symbols for both.

**Test**
1. **Delay:** transient, measure 50 %–50 % `in→out` rising-edge delay. Tune loads
   to $\tau_1=4t_0$, $\tau_2=3t_0$ (e.g. 60/45 ps) in TT@27 °C, so
   $t_0=\tau_1-\tau_2=15\,\text{ps}=\gcd(\tau_1,\tau_2)$ ([`07`](07-paper-2d-vernier-design-notes.md) §1.2).
2. **Corner safety:** sweep $\{TT,SS,FF,SF,FS\}\times\{-40,27,150\}$ °C; confirm
   **$\tau_2>0$ and $\tau_1-\tau_2>0$ in FF@−40 °C** (the corner that collapses
   the LSB). Resize with ≥5 ps headroom or use the trim caps.
3. **Edge quality:** check the `out` rise time into one `srlatch` input cap is
   sharp (the 2nd inverter's job).

**Sign-off:** $\tau_1,\tau_2$ on target in TT; $\tau_1-\tau_2>0$ in all 15 corners.

---

## Phase 3 — 1-D Vernier row (sanity check before the grid)

Catch matching/arbiter bugs on a tiny circuit, per [`04`](04-implementation-plan.md) Phase 2.

**Build** (scratch top in `tdc_2d_vernier`)
- Start line: 8× `delay_tau1` in series, tap after each stage.
- Stop line: 8× `delay_tau2` in series, tap after each stage.
- 8 `srlatch`, arbiter *k* compares Start-tap *k* vs Stop-tap *k*.
- Drive both lines from two `vpulse` with a controllable skew `delay`; wire
  `RESET` to all latches.

**Test**
1. Sweep `delay` 0 → $8t_0$ in 1 ps steps; the count of fired arbiters must rise
   **monotonically**, one extra per $t_0$.
2. Extract LSB = measured step width; confirm $\approx\tau_1-\tau_2$.

**Sign-off:** monotonic 0→8 code, $|\mathrm{DNL}|<0.5$ LSB in TT.

---

## Phase 4 — the 2-D grid → `tdc_core`

Now the real core. Build the routing table on paper first, then wire it.

**4a. Routing table (paper-and-pencil, 20 min)**
- Choose grid: start **8×8** (triangular $j\le i$, 36 cells, 31 used). Optionally
  asymmetric (more X stages) if diagonal-crossing DNL shows up later ([`07`](07-paper-2d-vernier-design-notes.md) §7).
- For every cell $(i,j)$ compute $\Delta t_{i,j}=i\,\tau_1-j\,\tau_2=(4i-3j)\,t_0$.
- Sort the reachable $\Delta t$ into the 31 ordered levels. **Cells sharing a
  level (diagonal $i-j=k$) OR together into thermometer bit $q_k$** ([`01`](01-architecture.md) §3).
  This table *is* your OR-tree wiring — keep it in the report.

**4b. Build `tdc_core`**
- Start delay line (X): chain of `delay_tau1`, tapped per stage.
- Stop delay line (Y): chain of `delay_tau2`, tapped per stage.
- Arbiter grid: one `srlatch` per used $(i,j)$; `S`←X-tap *i*, `R`←Y-tap *j*.
- **Dummy comparators**: put `srlatch` (or matched input caps) on the unused
  corner cells so **every tap sees identical load** ([`07`](07-paper-2d-vernier-design-notes.md) §2.3).
- OR-tree: per diagonal, `or_tree` (balanced `nor2`+inv) → `q1..q31`.
  Tie **`q32` to a fixed level** (spare; wrapper terminates it).
- Reset distribution: buffer `RESET` (reuse `Inv_3x`/`Inv_5x`) to every latch;
  balance the fan-out so all latches clear together.
- **Pins must equal `td` exactly:** `RESET`,`START`,`STOP`,`VDD`,`GND`,`q1..q32`.
  Generate the symbol; verify pin names/order match `td`'s symbol 1:1.

**Sign-off:** schematic Check-and-Save clean; pin list identical to `td`.

---

## Phase 5 — integrate into the provided testbench

**Build** = one edit, no new testbench.
1. Open `Testbench/TDC` (the wrapper). Select instance **`I13`** (currently `td`).
2. **Replace cellview** → `tdc_2d_vernier / tdc_core / symbol`. The
   `q1..q31→Q1..Q31` wiring, `q32` termination, and ammeters stay as-is.
   *(If a TA forbids editing `Testbench/TDC`: copy `TDC` into `tdc_2d_vernier`,
   re-point there, and instance that copy in a copied `TB_TDC` — same result.)*
3. Open `Testbench/TB_TDC` in ADE Explorer/Assembler.

**Test (single point first)**
- One transient at a mid-scale `delay` (e.g. 200 ps), TT@27 °C, `supply=1.8`.
- Probe `Q1..Q31`: expect a clean thermometer (all-1s up to the code, all-0s
  above) after STOP; RESET clears beforehand. Probe `/I1/VDD` current is sane.

**Sign-off:** one delay value gives a correct, bubble-free thermometer code in TT.

---

## Phase 6 — characterise (DNL/INL) with the OCEAN sweep

Use the pre-built script — **don't hand-roll the sweep**.

```bash
./run-testbench.sh thermometer   # codeLimit=31, 1 ps step; pulls results into ./results/
```

- It SSHes in, loads `testbench_tdc_therm.ocn`, sweeps `delay`, and returns
  `results_tdc_*.csv` + `log_tdc_*.txt` ([`03`](03-testbench.md)).
- From the CSV compute DNL/INL ($\mathrm{DNL}[k]=(w[k]-t_0)/t_0$,
  $\mathrm{INL}=\sum\mathrm{DNL}$).

**Sign-off (TT first):** no missing codes ($\mathrm{DNL}[k]>-1$ LSB ∀k),
$t_0<20\,\text{ps}$. Expect *periodic* INL/DNL (period = diagonal length) — and
if you see a non-periodic bump, suspect input coupling, not the architecture
([`07`](07-paper-2d-vernier-design-notes.md) §3.3).

---

## Phase 7 — corners + temperature

In the OCEAN script set `corners = ` `("tt" "ss" "ff" "snfp" "fnsp")` and sweep
$T\in\{-40,27,150\}$ °C (5×3 = 15 runs). Re-run `./run-testbench.sh thermometer`.

- If $\tau_2$ collapses (FF@−40 °C): bump the trim caps or resize `delay_tau2`.
- Keep every run's CSV/log for the report (15 DNL + 15 INL traces).

**Sign-off:** all 15 corner×temp runs pass — no missing codes, LSB < 20 ps.

---

## Phase 8 — energy / FoM, then package

1. **Energy** per [`03`](03-testbench.md): `energy = integ(-(VT("/VDD")*IT("/I1/VDD")) 0 sim_time)`.
2. **ΣW**: sum all transistor widths in `tdc_core` (script or by hand) — μm, per corner.
3. **FoM** $=P_\text{avg}/t_0=E_\text{conv}f_\text{conv}/t_0$; tabulate best/nominal/worst.
4. **Export** `tdc_2d_vernier`; plots through MATLAB ([`05`](05-deliverables.md)); fill the
   report/presentation sections.

**Sign-off:** results table locked; deliverable checklist in [`05`](05-deliverables.md) complete.

---

## Critical-path summary (where the time actually goes)

```
Phase 0  env+lib ........... 0.5 d   ← one-time
Phase 1  srlatch ........... 1–2 d   ← KEYSTONE, hardest; offset/MC sizing
Phase 2  delay_tau1/2 ...... 1 d     ← reuse Inv, tune load
Phase 3  1-D row ........... 0.5 d   ← cheap bug-catcher, don't skip
Phase 4  2-D grid+OR-tree .. 1–2 d   ← routing table + wiring
Phase 5  integrate ......... 0.5 d   ← one instance swap
Phase 6  DNL/INL (TT) ...... 0.5 d   ← provided script
Phase 7  corners ........... 1 d     ← 15 runs, resize if FF fails
Phase 8  energy/FoM/pack ... 1 d
```

**Three rules that keep it fast:** (1) reuse the inverters and the whole
testbench — build only `srlatch`, `delay_tau*`, and the grid; (2) get `srlatch`
right *before* anything else; (3) validate on the 1-D row before committing to
the 8×8 grid.

---

## Appendix A — Tuning knobs (after assembly)

Turn these in Phases 6–7 to hit spec. **$t_0=\tau_1-\tau_2$ is a small
difference of two large delays → the most sensitive knob:** keep `delay_tau1`
and `delay_tau2` the *same topology, differing only in load*, tune the two
absolute delays loosely and the *difference* precisely with the trim caps.

**Primary**
| Knob | Where | Controls | How |
|---|---|---|---|
| $t_0=\tau_1-\tau_2$ | load *difference* `delay_tau1`↔`delay_tau2` | resolution (LSB) | coarse: MOS-cap/fan-out; fine: switchable trim caps |
| absolute $\tau$ | tap inverter (`Inv`/`Inv_2x`) + load | speed, jitter, power | stronger tap → faster, lower jitter, more power |
| grid $N_X\times N_Y$ | # stages line X / Y | range (# codes) | extend range by adding **line-X stages only** |
| `srlatch` input/feedback $W$ | arbiter device sizing | DNL (offset) + dead-zone | up-size inputs → lower offset; stronger feedback → smaller dead-zone |

**Secondary (linearity):** dummy-comparator load matching (corner cells);
OR-tree depth balancing (high-code INL); RESET fan-out balancing; routing/OR
mapping choice. **Global:** `supply`/VDD (delays scale, $P\propto V^2$),
channel $L$ (normally pinned 180 n). **Testbench/ADE:** `delay`+`timeStep`,
`corners`, temperature, `codeLimit=31`, `transientSimTime`, `delayscale`, RESET width.

**Symptom → knob**
| Symptom | Knob |
|---|---|
| LSB off-target | $\tau_1/\tau_2$ load difference → trim caps |
| $\tau_2\le0$ in FF/−40 °C | more $\tau_1-\tau_2$ headroom; trim; resize `delay_tau2` |
| missing codes / DNL < −1 LSB | up-size `srlatch` inputs; check dummy loading + matching |
| INL grows at high codes | balance OR-tree; per-corner trim |
| dead-zone too wide | stronger latch feedback; sharper edges; more settle time |
| power / FoM too high | weaker taps; fewer stages; fewer engaged trim caps; lower supply |
| $\sum W$ too high | smaller latch/inverter $W$; fewer dummies |
