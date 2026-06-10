% 1-D Vernier row vs 2-D Vernier core comparison.
% Reads v1d_tt.csv (dt,code,energy), the 2-D TT data from ~/sims/tdc_corners,
% renders into repo results/vernier1d_vs_2d/.

outdir = fullfile(getenv('HOME'), 'tud-digital-ic-design-2', 'results', 'vernier1d_vs_2d');
if ~exist(outdir, 'dir'), mkdir(outdir); end

V = readtable(fullfile(getenv('HOME'), 'sims', 'v1d_cmp', 'v1d_tt.csv'));

% 2-D TT transition table from the untuned corner run (same trim-style: fixed config)
U = struct('trans', []);
rl = strsplit(fileread(fullfile(getenv('HOME'), 'sims', 'tdc_corners', 'results_tt.csv')), '\n');
for ii = 1:numel(rl)
    nums = sscanf(strtrim(rl{ii}), '%g\t%d');
    if numel(nums) == 2, U.trans(end+1,:) = nums(:)'; end
end

%% 1-D transitions from the staircase
dt = V.dt_s; code = V.code;
tr = [];   % [dt_of_transition, new_code]
for ii = 2:numel(dt)
    if code(ii) > code(ii-1), tr(end+1,:) = [dt(ii) code(ii)]; end %#ok<*SAGROW>
end
steps1 = diff(tr(:,1)); res1 = mean(steps1);
dnl1 = steps1/res1 - 1;
inl1 = (tr(:,1) - tr(1,1) - (tr(:,2)-tr(1,2))*res1)/res1;

steps2 = diff(U.trans(:,1)); res2 = mean(steps2);
dnl2 = steps2/res2 - 1;

%% Plot 1: 1-D staircase
fig = figure('Visible','off','Position',[0 0 900 600]);
stairs(dt*1e12, code, 'LineWidth', 1.5); grid on;
xlabel('STOP-START skew (ps)'); ylabel('output code');
title(sprintf('1-D Vernier row transfer (TT, 27\\circC) — LSB = %.2f ps, 8 codes', res1*1e12));
print(fig, fullfile(outdir, 'v1d_staircase.png'), '-dpng', '-r150');

%% Plot 2: DNL comparison — the column-wrap hypothesis test
fig2 = figure('Visible','off','Position',[0 0 950 620]); hold on; grid on;
plot(U.trans(2:end,2), dnl2, '.-', 'LineWidth', 1.2, 'Color', [0.85 0.4 0.2]);
plot(tr(2:end,2), dnl1, 'o-', 'LineWidth', 1.6, 'Color', [0.2 0.45 0.85], 'MarkerFaceColor', [0.2 0.45 0.85]);
xline(7,'k:'); xline(13,'k:'); xline(19,'k:'); xline(25,'k:');
xlabel('output code'); ylabel('DNL (LSB)');
title(sprintf(['DNL, same cells & sizing: 1-D row (unequalized taps, LSB %.1f ps) vs 2-D grid (equalized, LSB %.2f ps)\n' ...
  '1-D DNL_{max} = %.2f LSB (collapsed step at code 2); 2-D DNL_{max} = %.2f LSB (k=6 wrap sawtooth, dotted)'], ...
  res1*1e12, res2*1e12, max(abs(dnl1)), max(abs(dnl2))));
legend({'2-D grid (codes 2..31)','1-D row (codes 2..8)'}, 'Location','best');
print(fig2, fullfile(outdir, 'dnl_1d_vs_2d.png'), '-dpng', '-r150');

%% Plot 3: hardware scaling (analytic, design points marked)
fig3 = figure('Visible','off','Position',[0 0 900 600]); hold on; grid on;
N = 4:64;
st1 = 2*N;                                   % 1-D: N tau1 + N tau2
k = 6; st2 = ceil(N/k) + k + 2;              % 2-D: N_X + N_Y (+ input stages)
plot(N, st1, 'LineWidth', 1.6); plot(N, st2, 'LineWidth', 1.6);
plot(8, 16, 'ko', 'MarkerFaceColor','b', 'MarkerSize', 9);
plot(31, 18, 'ko', 'MarkerFaceColor','r', 'MarkerSize', 9);
text(9, 18, '1-D row (built): 8 codes / 16 stages');
text(31, 22, {'2-D grid (built):','31 codes / 18 stages'}, 'HorizontalAlignment','center');
xlabel('number of output codes N'); ylabel('delay stages required');
title('Delay-line hardware vs resolution: 1-D (2N) vs 2-D Vernier (N/k + k)');
legend({'1-D Vernier','2-D Vernier (k=6)'}, 'Location','northwest');
print(fig3, fullfile(outdir, 'scaling_1d_vs_2d.png'), '-dpng', '-r150');

%% Summary
efile = fullfile(getenv('HOME'), 'sims', 'v1d_cmp', 'v1d_energy2.csv');
e1 = NaN;
if exist(efile, 'file')
    E = readtable(efile);
    e1 = mean(E.energy_J(E.energy_J>0));
end
fid = fopen(fullfile(outdir, 'v1d_vs_2d_summary.txt'), 'w');
fprintf(fid, '1-D Vernier row vs 2-D Vernier core (both: same delay_tau1/tau2/srlatch cells,\n');
fprintf(fid, 'same tuned sizing, TT 27C; 1-D trim hardwired all-on -> predicted t0=16.6ps)\n\n');
fprintf(fid, '%-28s %-14s %-14s\n', 'metric', '1-D row', '2-D core');
fprintf(fid, '%-28s %-14s %-14s\n', 'codes', '8', '31');
fprintf(fid, '%-28s %-14.2f %-14.2f\n', 'LSB (ps)', res1*1e12, res2*1e12);
fprintf(fid, '%-28s %-14.2f %-14.2f\n', 'DNL max (LSB)', max(abs(dnl1)), max(abs(dnl2)));
fprintf(fid, '%-28s %-14.2f %-14.2f\n', 'INL max (LSB)', max(abs(inl1)), NaN);
fprintf(fid, '%-28s %-14s %-14s\n', 'delay stages (t1+t2)', '16', '18');
fprintf(fid, '%-28s %-14s %-14s\n', 'arbiters (incl dummies)', '8', '60');
fprintf(fid, '%-28s %-14.1f %-14.1f\n', 'sigma-W total (um)', 651.28, 1305.57);
fprintf(fid, '%-28s %-14.1f %-14.1f\n', 'sigma-W per code (um)', 651.28/8, 1305.57/31);
fprintf(fid, '%-28s %-14.2f %-14.2f\n', 'E/conv (pJ)', e1*1e12, 11.67);
fprintf(fid, '%-28s %-14.3f %-14.3f\n', 'E per code (pJ)', e1*1e12/8, 11.67/31);
fprintf(fid, '%-28s %-14s %-14s\n', 'full-scale latency', '~8*tau1=0.85ns', '~10*tau1=0.9ns');
fprintf(fid, '\n31-code 1-D extrapolation: 31/8 * 651.3 = 2524 um sigma-W (1.9x the 2-D),\n');
fprintf(fid, '62 delay stages (3.4x), full-scale latency ~31*tau1 = 3.3 ns (3.7x).\n');
fclose(fid);

type(fullfile(outdir, 'v1d_vs_2d_summary.txt'));
disp('V1D_PLOTS_DONE');
