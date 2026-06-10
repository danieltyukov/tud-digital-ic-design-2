# 1-D Vernier row vs 2-D Vernier core (TT, 27 °C)

Same `delay_tau1`/`delay_tau2`/`srlatch` cells, same tuned sizing; the 1-D row
(`vernier2d/vernier1d_row`, 8 codes) has trim pins hardwired all-ON and **no
fan-out equalization** (each tap drives 1 latch, not the 10-load environment
the cells were sized for). See `v1d_vs_2d_summary.txt` for the full table.

| metric | 1-D row | 2-D core |
|---|---|---|
| codes | 8 | 31 |
| LSB | **28.6 ps** (uniform ~33 ps, one collapsed 3 ps step) | **15.35 ps** |
| DNL max | 0.89 (collapsed step at code 2) | 0.66 (k=6 wrap sawtooth) |
| offset | ~+42 ps | −15 ps |
| ΣW / per code | 651 µm / **81.4 µm** | 1306 µm / **42.1 µm** |
| E/conv / per code | 2.62 pJ / 0.33 pJ | 11.67 pJ / 0.38 pJ |
| delay stages | 16 for 8 codes | 18 for 31 codes |

**Takeaways for the report:** (1) the measured LSB doubles (33 vs 16.6 ps
stage-level prediction) when taps are not loading-equalized — direct
experimental confirmation of the Phase-3 "loading insight" and the reason the
2-D grid pads to 10×10; (2) per code, 2-D is ~2× more area-efficient
(extrapolated 31-code 1-D: 2524 µm ΣW = 1.9×, 62 stages = 3.4×, 3.3 ns
latency = 3.7×); (3) the 8-code 1-D row consumes the same delay-line hardware
(16 stages) as the entire 31-code 2-D grid (18).

Plots: `v1d_staircase.png`, `dnl_1d_vs_2d.png` (same-cells DNL comparison),
`scaling_1d_vs_2d.png` (2N vs N/k+k with built design points). Scripts:
`v1d_staircase_v2.ocn` (321-run sweep), `v1d_energy2.ocn` (pin-current energy
via `i("/I0/VDD")`), `plot_v1d.m`. Data: `v1d_tt.csv`, `v1d_energy2.csv`.
