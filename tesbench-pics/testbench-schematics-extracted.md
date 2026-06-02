# Testbench library — schematics & symbols, extracted

> **What this is.** A cell-by-cell description of the Cadence `Testbench`
> library, read directly off the schematic/symbol screenshots in this folder
> (`tesbench-pics/*.png`). The `.oa` files on disk are OpenAccess binary and
> can't be read as text, so these PNG exports are the ground truth.
>
> **Why it exists.** So future chats about the 2-D Vernier TDC have an exact
> map of the harness we plug into: what every block does, every pin, every
> device size, and — crucially — **where our design actually goes**.
>
> Cross-reference: this confirms/corrects [`../project-details/03-testbench.md`](../project-details/03-testbench.md)
> and feeds [`../project-details/04-implementation-plan.md`](../project-details/04-implementation-plan.md).
> Math is LaTeX per this repo's `CLAUDE.md` override.

---

## 0. Library context (from the Library Manager screenshot)

The server home has many libraries (`SCPC2025`, `SMPC`, `SMPC_Project_Work`,
`Tutorial*`, `ahdlLib`, `analogLib`, `assignment*_et4382`, `ee4610`,
`tsmc18`, `cdsDefTechLib`, …). The one that matters for us is **`Testbench`**,
whose cells are:

```
Inv   Inv_2x   Inv_2x_chain   Inv_3x   Inv_5x   Inv_20x
Mux   POWER    TB_TDC         TDC      TDC_in   TDC_in_tb
TDC_out   td   txg
```

Every cell carries explicit **`VDD`/`GND` pins** (no global supply nets) — a
hard rule from the brief, so all power flows through the `POWER` block and can
be current-sensed.

All transistors are **`tsmc18` 2 V devices** (`nmos2v` = `"nch"`,
`pmos2v` = `"pch"`), drawn at minimum channel length $L = 180\,\text{nm}$.

---

## 1. The signal chain at a glance

```
                         ┌─────────┐
                         │  POWER  │  I1   VDD_TB, VDD, GND
                         └──┬───┬──┘
              VDD_TB ◄──────┘   └──────► VDD / GND bus
                 │                 │            │
            ┌────┴────┐       ┌────┴─────────┐  │   ┌──────────┐
   (PWL/    │ TDC_in  │ RESET │     TDC      │ Q1│   │ TDC_out  │
    pulse   │   I0    ├──────►│  (DUT wrap)  ├───┼──►│   I3     ├─► b1..b31
    srcs)   │         │ START │   = td core  │ . │   │ +1fF/out │   (loaded
            │         ├──────►│  + Ammeters  │ . │   │          │    probes)
            │         │ STOP  │              │Q31│   │          │
            └─────────┘──────►└──────────────┘───┴──►└──────────┘
```

- **`POWER` (I1)** powers everything; supplies the DUT on `VDD` (current-sensed)
  and the testbench/stimulus on a *separate* `VDD_TB`.
- **`TDC_in` (I0)** turns ideal sources into clean `RESET/START/STOP` edges.
- **`TDC`** is the device under test. As shipped it is a **wrapper** around an
  empty core cell **`td`** — *that empty `td` is where our Vernier design goes.*
- **`TDC_out` (I3)** puts a realistic buffered + capacitive load on each of the
  31 outputs.

---

## 2. Hierarchy cells

### 2.1 `TB_TDC` — top-level testbench (`TB_TDC.png`)

Wires the four blocks together. Observed instances and nets:

| Instance | Cell    | Connections                                                        |
|----------|---------|--------------------------------------------------------------------|
| `I1`     | POWER   | pins `VDD_TB`, `VDD`, `GND` → drives the supply bus                 |
| `I0`     | TDC_in  | top `VDD`/`GND`; right outputs `RESET`, `START`, `STOP`            |
| *(mid)*  | TDC     | left inputs `RESET/START/STOP`; top `VDD/GND`; right `Q1..Q31`     |
| `I3`     | TDC_out | left inputs `Q1..Q31` (labelled `D1..D31` inside); top `VDD/GND`   |

Nets crossing the top level: `VDD_TB`, `VDD`, `GND`, `RESET`, `START`, `STOP`,
and the 31-wide output bus `Q1..Q31`. The `START/STOP/RESET` wires run from
`TDC_in`'s right edge straight into the `TDC`'s left edge.

### 2.2 `POWER` — supply + current sense (`POWER.png`)

Three output pins, each fed from a DC source through a 0-valued series source
used as an **ammeter** (the standard Spectre current-probe trick):

| Pin       | Source chain                                  | Meaning                                            |
|-----------|-----------------------------------------------|----------------------------------------------------|
| `VDD`     | `V0` (`vdc=supply`) → `V5` (`vdc=0`) → `VDD`   | DUT core supply, with `V5` as the **0 V current sense** (net `VDD1` between them) |
| `VDD_TB`  | `V2` (`vdc=supply`) → `VDD_TB`                 | **Separate** copy of the supply for the input drivers, so their switching current does *not* pollute the DUT $I_{DD}$ |
| `GND`     | `V4` (`vdc=0`) → global `gnd`                  | Ground return, with `V4` as the 0 V ground-current sense |

`vdc=supply` reads the ADE design variable **`supply`** (set to 1.8 V nominal,
swept for corners). This is why energy is integrated against `/I1/VDD` — `I1`
is this block, and `/I1/VDD` is the sensed core-supply branch.

### 2.3 `TDC_in` — stimulus generator (`TDC_in.png`)

Three identical rows, each = *ideal source → two `Inv_3x` buffers → output*:

| Output  | Source            | Source params                  | Buffers       |
|---------|-------------------|--------------------------------|---------------|
| `START` | `V0`              | PWL, `t1=0`, `v1:0`, `tvpairs=3` | `Inv_3x` ×2 (`I0`,`I1`) |
| `STOP`  | `V1`              | PWL, `t1=0`, `v1:0`, `tvpairs=3` | `Inv_3x` ×2 (`I7`,`I6`) |
| `RESET` | `V2`              | pulse, `v1:0`, `v2=supply`     | `Inv_3x` ×2 (`I8`,`I9`) |

The two cascaded `Inv_3x` per line restore a full-swing CMOS edge with a
realistic slope (an even number → non-inverting). The **START↔STOP time
difference is the quantity the TDC measures**; in ADE this is the swept `delay`
variable, so $\Delta t = t_\text{stop} - t_\text{start} = \texttt{delay}$.
`RESET` is the short pulse that clears the arbiters before each START/STOP pair.
Pins: in `VDD`, `GND`; out `RESET`, `START`, `STOP`.

### 2.4 `TDC` — DUT wrapper, **our design entry point** (`TDC.png`)

This is the cell the brief calls "your design," but as shipped it is a thin
wrapper. Observed contents:

- One instance **`I13` of cell `td`** — the actual converter core.
- Core I/O passes straight through: `RESET/START/STOP` in, `VDD/GND` in.
- **Output remap:** `td` exposes `q1..q32`; the wrapper ties
  **`q1..q31 → Q1..Q31`** (the 31 thermometer outputs the testbench reads) and
  **terminates `q32`** through current source `I7` (`idc=0`) to `gnd` — i.e. the
  32nd tap is a dummy/terminator, not exported.
- **Instrumentation on the rails:** `V0` (`vdc=0`) sits in-line in the core
  `VDD` path (per-core supply ammeter), and `I2`,`I5` (`idc=0`) sit on the
  `gnd` reference. These are 0-valued probe sources — measurement only, no
  effect on logic.

> **Key takeaway:** the converter we build lives inside **`td`**, and `td` as
> shipped is *empty* (see §2.5). The `TDC` wrapper around it (ammeters +
> `q32` termination + `q→Q` rename) is fixed harness — don't fight it, fill
> the core.

### 2.5 `td` — the empty converter core (`td.png`, `td-symbol.png`)

The schematic is **interface-only**: just pin terminals, no transistors, no
wires. This is the **blank canvas** for the 2-D Vernier TDC.

- Inputs (left): `RESET`, `START`, `STOP`. Top: `VDD`, `GND`.
- Outputs (right): `q1 … q32` (two columns; symbol confirms `q1..q32`).

Mapping to our spec: `q1..q31` become the thermometer code $Q_1..Q_{31}$;
`q32` is swallowed by the wrapper. So the core must emit a **31-step
thermometer** plus one spare tap.

### 2.6 `TDC_out` — output load / readout (`TDC_out.png`, `TDC_out2.png`)

One row per output. Each row = *input `Dn` → two `Inv_2x` buffers → node `bn`
→ `1 fF` capacitor to ground*:

```
 D1 ─►[Inv_2x I0]─►[Inv_2x I1]─► b1 ─||─ C0 (c=1f)
 D2 ─►[Inv_2x I5]─►[Inv_2x I3]─► b2 ─||─ C1 (c=1f)
 D3 ─► …                       ─► b3 ─||─ C2 (c=1f)
 …  (D1..D31)
```

`D1..D31` here are the same nets as the TDC's `Q1..Q31`. Function: present a
**fixed, realistic capacitive load** ($2\times$ `Inv_2x` gate load + 1 fF) on
every output so the core's drive strength and switching energy are measured
under load, and give clean probe nodes `b1..b31`. Pins: in `VDD`, `GND`,
`D1..D31`.

### 2.7 `TDC_in_tb` — stand-alone input testbench (`TDC_in_tb.png`)

A small testbench that exercises **`TDC_in` on its own** (verify the
START/STOP/RESET waveforms and the `delay` timing before running the whole
chain). Not part of `TB_TDC`; a bring-up aid.

---

## 3. Primitive / building-block cells

### 3.1 Inverter family (`Inv*.png`)

All are the same complementary CMOS inverter (`pmos2v` pull-up `M1`,
`nmos2v` pull-down `M0`, `L = 180\,\text{nm}`), scaled by **fingers**. The unit
device is $W_p = 440\,\text{nm}$, $W_n = 220\,\text{nm}$ (a 2:1 P:N ratio to
balance $\mu_n \approx 2\mu_p$). Total widths:

| Cell      | fingers | $W_p$ total      | $W_n$ total      | Notes                          |
|-----------|:-------:|------------------|------------------|--------------------------------|
| `Inv`     | 1       | 440 nm           | 220 nm           | unit / $\times 1$              |
| `Inv_2x`  | 2       | 880 nm           | 440 nm           |                                |
| `Inv_3x`  | 3       | 1.32 µm          | 660 nm           | used in `TDC_in` buffers       |
| `Inv_5x`  | 5       | 2.2 µm           | 1.1 µm           |                                |
| `Inv_20x` | **10**  | 4.4 µm           | 2.2 µm           | ⚠️ named "20×" but drawn with **10 fingers** (≈10× the unit width), not 20 |

Pins on each: `in`, `out`, `VDD`, `GND`.

### 3.2 `txg` — CMOS transmission gate (`txg.png`)

Parallel pass-gate: `pmos2v M1` (`w=440n`, gate = **`ckb`**) in parallel with
`nmos2v M0` (`w=220n`, gate = **`ck`**), both `L=180n`, single finger. Bodies
to `vdd`/`gnd`. Pins: `in`, `out`, `ck`, `ckb`, `vdd`, `gnd`. A clocked analog
switch — conducts when `ck=1`/`ckb=0`.

### 3.3 `Mux` — 2:1 transmission-gate multiplexer (`MUX.png`)

Two `txg` instances select between inputs `In0` and `In1`; an internal `Inv`
(`I21`) makes the complementary select (`En` / `En_b`) so exactly one gate
conducts; the two gate outputs tie to `out`. (The capture also shows a local
`V0 vdc=1.8` + `gnd` — bench scaffolding around the cell, not part of the mux
proper.)

### 3.4 `Inv_2x_chain` — parallel buffer bank (`Inv_2x_chain.png`, `Inv_2x_chain2.png`)

A tall array (~16 rows) of independent non-inverting buffers, each row
`inpN → Inv_2x → Inv_2x → oN`. Same per-row structure as `TDC_out` minus the
load caps — a reusable multi-line buffer/delay bank.

---

## 4. How this maps onto our project docs

### 4.1 Confirmations of [`03-testbench.md`](../project-details/03-testbench.md) / [`02-specs.md`](../project-details/02-specs.md)

- ✅ `POWER` has a separate `VDD_TB` so only DUT current is measured — confirmed
  (`V2` feeds `VDD_TB`; `V5`=0 V senses core `VDD`).
- ✅ Inputs `RESET/START/STOP` each buffered by **$3\times$ min inverters** —
  confirmed (`Inv_3x`, two in series per line).
- ✅ `delay` = STOP−START interval, swept in ADE — consistent with the PWL
  `V0`/`V1` sources.
- ✅ Devices are `nmos2v`/`pmos2v` at $L=180\,\text{nm}$, explicit `VDD/GND`
  pins everywhere — confirmed.
- ✅ `Mux`/`txg` are leftovers from the **unused** 5-bit T2B decoder — they
  appear in the library but not in the `TB_TDC` signal path.

### 4.2 Corrections / details the docs didn't capture

| Topic | Doc said | Schematic actually shows |
|-------|----------|--------------------------|
| Output load per $Q$-line | "$5\times$ min-Inv" (`02-specs`, `03-testbench`) | **$2\times$ `Inv_2x`** in series **+ a 1 fF cap** to ground (`TDC_out`). Real load ≈ two 2× inverter gates plus 1 fF, *not* a 5× inverter. |
| `TDC` block | "your design goes here" | `TDC` is a **wrapper**: it instantiates core cell **`td`** (`I13`), adds supply ammeters, and terminates the 32nd tap. The editable core is **`td`**. |
| Output width | $Q_1..Q_{31}$ | Core `td` actually has **`q1..q32`**; `q32` is terminated in the wrapper, `q1..q31 → Q1..Q31`. |
| `Inv_20x` | (implied 20×) | Drawn as **10 fingers** (4.4 µm / 2.2 µm) ≈ 10× the unit inverter. |
| Cells not in the doc table | — | `td`, `Inv_2x_chain`, `TDC_in_tb`, `TDC_out2` exist in the library and are described above. |

### 4.3 What it means for [`04-implementation-plan.md`](../project-details/04-implementation-plan.md)

- Our **Phase 1–3** work (delay cells, arbiter DFFs, OR-tree) must land inside
  the **`td` interface**: in `RESET/START/STOP/VDD/GND`, out `q1..q32` where
  `q1..q31` is the thermometer code and `q32` is a spare.
- Whether we build in `td` itself or in our own library cell that we then drop
  in for `I13` is the one open question — but the **pin contract is fixed by
  `td`'s symbol**, so match it exactly (`q1..q32`, explicit `VDD/GND`).
- The plan's load assumption should use the **real** `TDC_out` load
  ($2\times$`Inv_2x` + 1 fF), not a 5× inverter, when sizing the core's output
  drive and computing energy.
- `Inv`, `Inv_2x`, `Inv_3x`, `Inv_5x` (the unit + finger-scaled drivers) are
  available as ready references for our own `inv_min`/`inv_2x`/`inv_3x` cells —
  same 440/220 nm unit, same 2:1 ratio.

---

## 5. Quick pin reference

| Cell      | Inputs                          | Outputs / loads          | Supply       |
|-----------|---------------------------------|--------------------------|--------------|
| POWER     | (sources internal)              | `VDD`, `VDD_TB`, `GND`   | —            |
| TDC_in    | —                               | `RESET`, `START`, `STOP` | `VDD`,`GND`  |
| TDC       | `RESET`,`START`,`STOP`          | `Q1..Q31`                | `VDD`,`GND`  |
| td (core) | `RESET`,`START`,`STOP`          | `q1..q32`                | `VDD`,`GND`  |
| TDC_out   | `D1..D31`                       | `b1..b31` (+1 fF probes) | `VDD`,`GND`  |
| Inv*      | `in`                            | `out`                    | `VDD`,`GND`  |
| txg       | `in`,`ck`,`ckb`                 | `out`                    | `vdd`,`gnd`  |
| Mux       | `In0`,`In1`,`En`                | `out`                    | `VDD`,`GND`  |
| Inv_2x_chain | `inp1..inpN`                 | `o1..oN`                 | `VDD`,`GND`  |
