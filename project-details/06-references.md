# References — 2-D Vernier TDC

## Anchor papers (course-recommended for our architecture)

1. **Liscidini, Vercesi & Castello, "Time to Digital Converter based on a 2-Dimensions Vernier Architecture," CICC 2009.** ← the original 2-D Vernier idea.
2. **Vercesi, Liscidini & Castello, "Two-Dimensions Vernier Time-to-Digital Converter," IEEE Journal of Solid-State Circuits, Aug 2010, vol. 45, no. 8, pp. 1504–1512.** ← the polished journal version of the same architecture.

## Background TDC literature (we'll cite at least one when discussing alternatives)

3. Staszewski *et al.*, "Time-to-Digital Converter for RF Frequency Synthesis in 90 nm CMOS," RFIC 2005 — Flash TDC.
4. Dudek, Szczepański & Hatfield, "A High-Resolution CMOS Time-to-Digital Converter Utilizing a Vernier Delay Line," IEEE JSSC, Feb 2000 — 1-D Vernier original.
5. Yu, Dai & Jaeger, "A 12-Bit Vernier Ring Time-to-Digital Converter in 0.13 µm CMOS Technology," IEEE JSSC, Apr 2010.
6. Henzler *et al.*, "A Local Passive Time Interpolation Concept for Variation-Tolerant High-Resolution Time-to-Digital Conversion," IEEE JSSC, Jul 2008 — Interpolating.
7. Kim *et al.*, "A 7-bit 3.75-ps Resolution Two-Step Time-to-Digital Converter in 65-nm CMOS Using Pulse-Train Time Amplifier," IEEE JSSC, Apr 2013 — Two-step + TA.
8. Lee & Abidi, "A 9 b, 1.25 ps Resolution Coarse-Fine Time-to-Digital Converter in 90 nm CMOS that Amplifies a Time Residue," IEEE JSSC, Apr 2008.
9. Straayer & Perrott, "A Multi-Path Gated Ring Oscillator TDC with First-Order Noise Shaping," IEEE JSSC, Apr 2009 — GRO bonus topology.

## Reference book

- S. Henzler, *Time-to-Digital Converters*, Springer Series in Advanced Microelectronics, 2010. DOI 10.1007/978-90-481-8628-0.

## Internal course material

- EE4615 Project Details (Q4 2026 briefing): see `tutorials/` and the parent
  notes folder at `tud-notes/Q4/EE4615/`.
- Lecture 2 slides 28–31 (2-D Vernier intro).
- EE4615 Testbench Instructions, April 2026.
- EE4615 Corner Analysis Manual, April 2026.

## Useful equations (cross-reference for the report)

Vernier resolution:

$$
t_0 = \tau_1 - \tau_2.
$$

Range of a $K$-stage chain:

$$
T_\text{range} = K \, t_0.
$$

Two-dim coverage for an $N \times N$ grid (triangular half):

$$
N_\text{codes} = \binom{N+1}{2} = \tfrac{N(N+1)}{2}.
$$

DNL / INL:

$$
\mathrm{DNL}[k] = \frac{w[k] - t_0}{t_0},\qquad
\mathrm{INL}[k] = \sum_{i=0}^{k} \mathrm{DNL}[i].
$$
