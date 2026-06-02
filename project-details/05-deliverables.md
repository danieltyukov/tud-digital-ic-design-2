# Deliverables checklist

## Cadence design submission

- [ ] Library `tdc_2d_vernier` exported, including all custom cells (`srlatch`, `delay_tau1/2`, `nand2`, `nor2`, `or_tree`, `tdc_core`). Inverters are **reused from the provided `Testbench` library** (hand-built CMOS, not `tsmc18` digital). No `analogLib` macros in the TDC core — realize delay loading with MOS-caps / fan-out, not an ideal `cap`.
- [ ] `TDC` wrapper's `I13` instance **re-pointed** from `td` to our `tdc_core` (the wrapper — with its supply ammeters `/I1/VDD` and `q32` termination — is kept, *not* replaced). `tdc_core` matches the `td` pin contract (`q1..q31` thermometer, `q32` spare).
- [ ] OCEAN runs (`results_tdc_therm.csv` + log) for all 5 corners × 3 temperatures attached.
- [ ] Every schematic and symbol has explicit `VDD` / `GND` pins (no global nets in the TDC).

## Report (≤ 25 % of grade, "documentation not essay")

- [ ] Title page — names, NetID, student numbers, class, date.
- [ ] Abstract — what we did + headline numbers (LSB, DNL/INL, FoM).
- [ ] Introduction — context (LiDAR, ADPLL), design boundaries, our objectives, state-of-the-art table (Vernier, 2-D, Two-step, GRO).
- [ ] Design body
  - 2-D Vernier architecture diagram.
  - Cell-level schematics with sized transistors.
  - τ₁, τ₂ sizing justification (one paragraph each, with the corner sweep numbers).
  - Arbiter choice + measured metastability curve.
  - OR-tree topology + skew budget.
- [ ] Results
  - DNL plot per corner (5 corners × 3 temperatures = 15 traces, or one figure per corner).
  - INL plot per corner.
  - Power vs delay sweep.
  - Energy / conversion table.
  - ΣW transistor-area number.
  - FoM table.
- [ ] Conclusion — claim vs. number, no new info.
- [ ] References — anchor papers (see `06-references.md`).
- [ ] Appendices — derivations, full sweep tables.

## Presentation (≤ 25 % of grade)

- [ ] 10-min talk + 5-min Q&A.
- [ ] Both members present technical content — *not* "A does intro, B does the rest".
- [ ] Slide ordering: title → intro → design choices (what / why / how) → results → recommendations / future → conclusion.
- [ ] Slides clearly show the breakdown of work between the two members.

## Bonus (optional)

- [ ] **TDC for ADC** (voltage-to-time conversion). If we ship this, it goes in a separate appendix and gets its own simulation plots.

## Submission deadlines (TU Delft Q4 2026)

| Item                  | Date              |
|------------------------|-------------------|
| Topic chosen (done)    | 29 Apr 2026       |
| Final presentation     | 8 – 12 Jun 2026   |
| Report + design        | **15 Jun 2026**   |

Late penalty: 0.1 pt/day, capped at 1.0 pt.
