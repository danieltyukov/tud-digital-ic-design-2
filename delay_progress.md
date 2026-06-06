# Technical Design Log: 2-D Vernier TDC Optimization

**Process:** TSMC 180 nm BCD (`nmos2v`/`pmos2v`)  
**Target Specification:** 5-bit output, Resolution ($t_0$) < 20 ps, Optimized FoM  

---

## 1. Executive Summary & Current Status
We have successfully transitioned from an idealized mathematical model to a physically realizable circuit architecture in the TSMC 180 nm process space. By abandoning the classical digital Fan-Out-of-4 (FO=4) paradigm and establishing an architectural multiplier strategy ($k=6$), we have found a clear path to achieve a highly stable **$t_0 = 15\text{ ps}$** time resolution across all process corners.

The architecture is locked into an asymmetric logical **10×6 matrix** to minimize active transistor width ($\sum W$) and dynamic power consumption. To maintain pristine structural matching and matching across process/temperature corners, this will be physically laid out as a symmetric **10×10 grid**, using dummy latch loads to pad out the unused rows and columns.

---

## 2. Chronological Design Evolution

### Phase 1: Breaking the FO=4 Bottleneck
* **Initial Setup:** Standard digital design guidelines suggested sizing the internal nodes of the delay cells with a classical Fan-Out-of-4 ratio ($\text{inv\_in} = 1\times, \text{inv\_out} = 4\times$).
* **The Problem:** The massive intrinsic delay of the internal node under an FO=4 constraint pinned the absolute minimum achievable delay at **97 ps**—even when the external load was minimized. This made it physically impossible to hit the aggressive delay targets ($\tau_2 \approx 45\text{–}60\text{ ps}$) required by initial, small-$k$ mathematical configurations.
* **The Solution:** We deviated from traditional digital sizing. Switching to a customized **FO=1** topology ($\text{inv\_in} = 2\times, \text{inv\_out} = 2\times$) dropped the internal node capacitance sharply, successfully lowering the base delay tuning window down to a highly responsive range of **74 ps to 147 ps**.

### Phase 2: Resolving Grid Loading & Architecture Math
* **The Challenge:** In a 2-D Vernier TDC, the line that must move faster ($\tau_2$, the Stop path) is physically routed to drive the heavy row load ($I_{max}$), while the slower line ($\tau_1$, the Start path) drives the lighter column load ($J_{max}$).
* **Mathematical Selection:** To balance fine time-resolution against these hardware constraints, we selected a target resolution of **$t_0 = 15\text{ ps}$** and a multiplier of **$k = 6$**.
  * This fixes the explicit target delays at:
    $$\tau_2 = (k - 1) \times t_0 = 5 \times 15\text{ ps} = \mathbf{75\text{ ps}}$$
    $$\tau_1 = k \times t_0 = 6 \times 15\text{ ps} = \mathbf{90\text{ ps}}$$
  * Mapping the maximum required 5-bit code ($m=31$) through the Vernier mapping equation $m = 6q + r$ outputs a strict logical architectural boundary of a **10×6 matrix** (Maximum Row Index $x=9$, Maximum Column Index $y=5$).

### Phase 3: The Loading Insight (The Technical Pivot)
* **The Discovery:** Initial simulations swept transistor size $S$ under a fixed standalone load of `m_load = 10` (representing 10 SR-latches). This suggested an $S=8\times$ inverter pair could hit 75 ps in the SS corner. However, this omitted a critical physical reality of a delay chain.
* **The Correction:** Because the delay line is a continuous cascade, a stage of size $S$ doesn't just charge the static latch inputs; it must also charge the input capacitance of the *next delay stage* in the chain. Since we are using an FO=1 delay stage layout, the input capacitance of the next stage scales up proportionally with $S$. The true equivalent load must therefore be increased to approximately **`20x`** (modeled explicitly as 10 latches + 1 downstream delay cell input).

---

## 3. Locked Architectural Framework

* **Time Resolution ($t_0$):** $15\text{ ps}$  *(Spec: $< 20\text{ ps}$)*
* **Multiplier ($k$):** $6 \implies \tau_1 : \tau_2 = 6 : 5$
* **Target Delays (Nominal TT @ 27°C):** $\tau_1 = 90\text{ ps}, \quad \tau_2 = 75\text{ ps}$
* **Logical Matrix Size:** $10 \times 6$ (10 rows for the $\tau_2$ line, 6 columns for the $\tau_1$ line)
* **Physical Matrix Size:** $10 \times 10$ (Symmetric array padded uniformly with dummy latch inputs)
* **Matching Strategy:** Twin-cell dummy loading (identical active transistor sizes for both chains to guarantee perfect tracking over environmental shifts).

---

## 4. Simulation Runbook & Next Steps

To implement the current design pivot, execute the following simulation procedure in Cadence Virtuoso:

### Step 1: Establish Core Active Sizing ($S$) in the SS Corner
1. Configure a delay stage testbench using two cascaded inverters with equal sizing multipliers $S$ ($\text{FO}=1$).
2. Configure the output loading to explicitly represent **10 SR-latch inputs + 1 next-stage delay stage input** (representing the true `20x` load environment).
3. Set the simulator corner to **SS @ 150°C** to guarantee the circuit can handle the absolute slowest operational bottleneck.
4. Run a parametric sweep over the sizing multiplier $S$ (e.g., from $8\times$ up to $24\times$). Identify the precise value of $S$ where the propagation delay drops to exactly **75 ps**.
5. **Lock this sizing $S$** globally. Use this exact active inverter size for every single delay stage (both active and dummy) across the entire matrix.

### Step 2: Calibrate the Slow Line ($\tau_1$) via Dummy Loads
Because active transistor sizing is now completely locked to ensure perfect matching, we will manipulate individual line speeds and adapt to process corners using explicit capacitive tuning blocks:

* **Tuning $\tau_1$:** Natively, the $\tau_1$ line only drives 6 real arbiters. Since it features the same drive strength $S$ but less load, it will run faster than 75 ps. In your testbench, fix the baseline load to 6 latches and place an additional variable dummy load (`m_dummy`) in parallel. Sweep `m_dummy` until the propagation delay slows down to exactly **90 ps**.
* **Global Corner Calibration (TT, FF, SF, FS):** When operating outside of the worst-case SS corner, the circuits will naturally speed up, causing $\tau_1$ and $\tau_2$ to contract. To protect your $15\text{ ps}$ LSB step and prevent catastrophic missing codes ($\text{DNL} \le -1$), implement a parameterized array of dummy MOS-switched capacitors at the output nodes. These blocks can be programmatically switched in or out per corner to keep the $\tau_1 - \tau_2$ delta locked at 15 ps.
