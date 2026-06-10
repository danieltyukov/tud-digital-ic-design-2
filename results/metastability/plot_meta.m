% Metastability curve plots for vernier2d/srlatch (TDC arbiter), TT 27C.
% Reads meta_coarse.csv + meta_fine.csv (+ meta_ultra.csv if present),
% writes PNGs + summary into ~/Desktop/tdc_metastability/.

outdir = fullfile(getenv('HOME'), 'tud-digital-ic-design-2', 'results', 'metastability');
if ~exist(outdir, 'dir'), mkdir(outdir); end
simdir = fullfile(getenv('HOME'), 'sims', 'srlatch_meta');

T = readtable(fullfile(simdir, 'meta_coarse.csv'));
F = readtable(fullfile(simdir, 'meta_fine.csv'));
T = [T; F];
ufile = fullfile(simdir, 'meta_ultra.csv');
if exist(ufile, 'file'), T = [T; readtable(ufile)]; end
[~, iu] = unique(T.dt_s); T = T(iu, :); T = sortrows(T, 'dt_s');

Vdd = 1.8;
t_arb = 202.5e-12;          % mid of S rising edge (tds=200p + 5p/2): arbitration instant
dt_ps = T.dt_s * 1e12;
fired = T.tq_cross_s > 0;
tdec_ps = (T.tq_cross_s - t_arb) * 1e12;

% Decision boundary: between last non-fired and first fired dt
lo = max(dt_ps(~fired & T.q_final_V < Vdd/2));
hi = min(dt_ps(fired));
dt0_ps = (lo + hi) / 2;
dz_ps = hi - lo;

% --- Plot 1: metastability curve (decision time vs overdrive) ---
fig = figure('Visible', 'off', 'Position', [0 0 900 620]);
x = dt_ps(fired) - dt0_ps;
y = tdec_ps(fired);
semilogx(x, y, 'o-', 'LineWidth', 1.4, 'MarkerSize', 6, 'MarkerFaceColor', [0.2 0.45 0.85]);
grid on; hold on;
% Fit tdec = c - tau*ln(dt-dt0) over the diverging region (exclude saturated tail)
sel = x < 5 & x > 1.5e-3;    % ps; tail flattens above 5 ps, sub-1.5fs points are dt0-uncertainty-limited
p = polyfit(log(x(sel)), y(sel), 1);
tau_ps = -p(1);
xf = logspace(log10(min(x)), log10(5), 50);
semilogx(xf, polyval(p, log(xf)), 'r--', 'LineWidth', 1.2);
xlabel('input overdrive  \Deltat - \Deltat_0  (ps)');
ylabel('arbiter decision time  t_{dec}  (ps, from arbitration instant)');
title(sprintf(['SR-latch arbiter metastability curve (TT, 27\\circC)\n' ...
    '\\tau_{reg} = %.1f ps   offset \\Deltat_0 = %+.4f ps   dead zone < %.0f fs'], ...
    tau_ps, dt0_ps, dz_ps*1000));
legend('measured', sprintf('fit: t_{dec} = %.0f - %.1f ln(\\Deltat'')  ps', p(2), tau_ps), ...
    'Location', 'northeast');
print(fig, fullfile(outdir, 'metastability_curve.png'), '-dpng', '-r150');

% --- Plot 2: decision transfer / dead zone ---
fig2 = figure('Visible', 'off', 'Position', [0 0 900 620]);
zoom_w = abs(dt_ps) <= 0.6;
plot(dt_ps(zoom_w), T.q_final_V(zoom_w), 'o-', 'LineWidth', 1.4, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.85 0.4 0.2]);
grid on; hold on;
xline(dt0_ps, 'r--', sprintf('\\Deltat_0 = %+.3f ps', dt0_ps), 'LineWidth', 1.2);
yline(Vdd/2, 'k:');
xlabel('\Deltat = t_R - t_S  (ps)   [\Deltat>0: S leads, latch should fire]');
ylabel('Q final value (V) at 1.95 ns');
title(sprintf(['Arbiter decision transfer (TT, 27\\circC)\n' ...
    'decision flips between %+.3f and %+.3f ps  ->  dead zone < %.0f fs ' ...
    '(LSB = 15 ps)'], lo, hi, dz_ps*1000));
ylim([-0.2 2.0]);
print(fig2, fullfile(outdir, 'deadzone_transfer.png'), '-dpng', '-r150');

% --- Summary ---
fid = fopen(fullfile(outdir, 'SUMMARY.txt'), 'w');
fprintf(fid, 'SR-latch arbiter (vernier2d/srlatch) metastability characterization\n');
fprintf(fid, 'Corner TT, 27 C, Vdd=1.8 V, 5 fF output loads, via srlatch_tb\n\n');
fprintf(fid, 'Arbitration offset dt0          : %+.3f ps (S must lead by this to fire)\n', dt0_ps);
fprintf(fid, 'Dead zone (decision ambiguity)  : < %.0f fs  (grid-limited bound)\n', dz_ps*1000);
fprintf(fid, 'Regeneration time constant tau  : %.1f ps (fit over overdrive < 5 ps)\n', tau_ps);
fprintf(fid, 'Nominal clk-Q delay (20 ps ovd) : %.1f ps\n', tdec_ps(end));
fprintf(fid, 'Max observed decision time      : %.1f ps (at %.2f fs overdrive)\n', max(y), min(x)*1000);
fprintf(fid, 'Verdict: dead zone (<1 fs) is >4 orders below the 15 ps LSB; offset (~0.15 ps) is ~1%% of LSB.\n');
if exist(ufile, 'file'), usrc = ', meta_ultra.csv'; else, usrc = ''; end
fprintf(fid, 'Points: %d sims. Sources: meta_coarse.csv, meta_fine.csv%s\n', height(T), usrc);
fclose(fid);

% copy raw data next to plots
copyfile(fullfile(simdir, 'meta_coarse.csv'), outdir);
copyfile(fullfile(simdir, 'meta_fine.csv'), outdir);
if exist(ufile, 'file'), copyfile(ufile, outdir); end
disp('PLOTS_DONE');
