% Tuned-corner analysis + tuned-vs-untuned comparison for TB_TDC.
% Reads tuned data from ~/sims/tdc_tuned, untuned from ~/sims/tdc_corners,
% calibration maps tune_<corner>.csv, chosen_configs.txt.
% Renders into repo results/tuned_corners/.

outdir = fullfile(getenv('HOME'), 'tud-digital-ic-design-2', 'results', 'tuned_corners');
if ~exist(outdir, 'dir'), mkdir(outdir); end
tdir = fullfile(getenv('HOME'), 'sims', 'tdc_tuned');
udir = fullfile(getenv('HOME'), 'sims', 'tdc_corners');
corners = {'tt','ss','ff','sf','fs'};
nC = numel(corners);
cols = lines(max(nC,7)); cols = cols(1:nC,:);

T = parseSet(tdir, corners);   % tuned
U = parseSet(udir, corners);   % untuned

%% ---- standard plots (tuned data) ----
fig = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    if isempty(T(c).runs), continue; end
    stairs(T(c).runs(:,1)*1e12, T(c).runs(:,2), 'LineWidth', 1.3, 'Color', cols(c,:));
end
xlabel('input delay (ps)'); ylabel('output code');
title('TDC transfer curve per corner — per-corner MOSCAP calibration applied');
legend(corners, 'Location','southeast');
print(fig, fullfile(outdir, 'staircase_all_corners.png'), '-dpng', '-r150');

fig2 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
fig3 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    tr = T(c).trans;
    if size(tr,1) < 3, continue; end
    d = tr(:,1); code = tr(:,2);
    steps = diff(d); res = mean(steps);
    T(c).lsb_ps = res*1e12;
    dnl = steps/res - 1;
    inl = (d - d(1) - (code - code(1))*res)/res;
    figure(fig2); plot(code(2:end), dnl, '.-', 'LineWidth', 1.2, 'Color', cols(c,:));
    figure(fig3); plot(code, inl, '.-', 'LineWidth', 1.2, 'Color', cols(c,:));
    T(c).dnl_max = max(abs(dnl)); T(c).inl_max = max(abs(inl));
end
figure(fig2); xlabel('output code'); ylabel('DNL (LSB)');
yline(-1,'r--','missing-code limit'); title('DNL per corner — calibrated');
legend(corners, 'Location','best');
print(fig2, fullfile(outdir, 'dnl_per_corner.png'), '-dpng', '-r150');
figure(fig3); xlabel('output code'); ylabel('INL (LSB)');
title('INL per corner — calibrated'); legend(corners, 'Location','best');
print(fig3, fullfile(outdir, 'inl_per_corner.png'), '-dpng', '-r150');

fig4 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    if isempty(T(c).runs), continue; end
    plot(T(c).runs(:,1)*1e12, T(c).runs(:,3)*1e12, '.-', 'LineWidth', 1.1, 'Color', cols(c,:));
end
xlabel('input delay (ps)'); ylabel('energy per conversion (pJ)');
title('Conversion energy vs input delay — calibrated'); legend(corners, 'Location','best');
print(fig4, fullfile(outdir, 'power_vs_delay.png'), '-dpng', '-r150');

%% ---- comparison 1: LSB per corner, untuned vs tuned ----
lsb_u = arrayfun(@(s) getmet(s,'Resolution')*1e12, U);
lsb_t = arrayfun(@(s) getmet(s,'Resolution')*1e12, T);
fig5 = figure('Visible','off','Position',[0 0 980 640]);
b = bar(categorical(corners, corners), [lsb_u(:) lsb_t(:)], 'grouped');
b(1).FaceColor = [0.65 0.65 0.65]; b(2).FaceColor = [0.2 0.45 0.85];
hold on; grid on;
yline(20, 'r--', 'spec  20 ps', 'LineWidth', 1.4);
yline(15, 'g--', 'target  15 ps', 'LineWidth', 1.4);
ylabel('LSB  t_0  (ps)');
legend({'untuned (fixed TT trim)','calibrated per corner'}, 'Location','northwest');
title('Resolution per corner: fixed trim vs per-corner MOSCAP-bank calibration');
for k = 1:nC
    text(k-0.15, lsb_u(k)+0.4, sprintf('%.1f', lsb_u(k)), 'HorizontalAlignment','center');
    text(k+0.15, lsb_t(k)+0.4, sprintf('%.1f', lsb_t(k)), 'HorizontalAlignment','center');
end
ylim([0 22]);
print(fig5, fullfile(outdir, 'lsb_tuned_vs_untuned.png'), '-dpng', '-r150');

%% ---- comparison 2: calibration range from the 64-config probe maps ----
fig6 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
bw1 = [2 20 21]; bw2 = [2 14 18];   % bank sizes (nf units), tau1 / tau2 side
for c = 1:nC
    M = readtable(fullfile(tdir, sprintf('tune_%s.csv', corners{c})));
    ok = M.t0_s > 0;
    du = (double(M.v0t1>0)*bw1(1) + double(M.v1t1>0)*bw1(2) + double(M.v2t1>0)*bw1(3)) ...
       - (double(M.v0t2>0)*bw2(1) + double(M.v1t2>0)*bw2(2) + double(M.v2t2>0)*bw2(3));
    scatter(du(ok), M.t0_s(ok)*1e12, 22, cols(c,:), 'filled');
end
yline(15, 'g--', 'target 15 ps', 'LineWidth', 1.4);
xlabel('engaged MOSCAP imbalance  \Delta_{cap} = units_{\tau1} - units_{\tau2}  (nf units)');
ylabel('stage-level  t_0 = \tau_1 - \tau_2  (ps)');
title('Calibration authority: t_0 vs trim-bank setting (64 configs \times 5 corners)');
legend(corners, 'Location','northwest');
print(fig6, fullfile(outdir, 'calibration_range.png'), '-dpng', '-r150');

%% ---- summary table ----
fid = fopen(fullfile(outdir, 'tuned_summary.txt'), 'w');
fprintf(fid, 'TB_TDC tuned-corner sweep (per-corner MOSCAP-bank calibration, 27 C, 1.8 V)\n');
fprintf(fid, 'Chosen configs (gate V t1-banks / t2-banks):\n');
cfg = strsplit(strtrim(fileread(fullfile(tdir, 'chosen_configs.txt'))), '\n');
for k = 1:numel(cfg), fprintf(fid, '  %s\n', cfg{k}); end
fprintf(fid, '\n%-6s %-6s | %-9s %-9s | %-8s %-8s | %-8s %-8s | %-10s %-8s %-10s\n', ...
    'corner','pass','LSB_unt','LSB_tun','DNL_unt','DNL_tun','INL_unt','INL_tun','E/conv(pJ)','ENOB','FoM(pJ/st)');
for c = 1:nC
    fprintf(fid, '%-6s %-6s | %-9.2f %-9.2f | %-8.2f %-8.2f | %-8.2f %-8.2f | %-10.3f %-8.3f %-10.3f\n', ...
        corners{c}, ternStr(~T(c).fail), lsb_u(c), lsb_t(c), ...
        getmet(U(c),'DNL'), getmet(T(c),'DNL'), getmet(U(c),'INL'), getmet(T(c),'INL'), ...
        getmet(T(c),'AverageEnergy')*1e12, getmet(T(c),'ENOB'), getmet(T(c),'FoM')*1e12);
end
spread_u = max(lsb_u)-min(lsb_u); spread_t = max(lsb_t)-min(lsb_t);
fprintf(fid, '\nLSB corner spread: %.2f ps untuned -> %.2f ps calibrated (%.0fx tighter)\n', ...
    spread_u, spread_t, spread_u/spread_t);
fclose(fid);

copyfile(fullfile(tdir, 'chosen_configs.txt'), outdir);
type(fullfile(outdir, 'tuned_summary.txt'));
disp('TUNED_PLOTS_DONE');

%% ---- local functions ----
function S = parseSet(simdir, corners)
S = struct([]);
for c = 1:numel(corners)
    S(c).name = corners{c};
    S(c).trans = []; S(c).runs = []; S(c).warn = {}; S(c).fail = false;
    S(c).metrics = struct();
    rl = strsplit(fileread(fullfile(simdir, sprintf('results_%s.csv', corners{c}))), '\n');
    for ii = 1:numel(rl)
        L = strtrim(rl{ii});
        if isempty(L) || strncmp(L,'Delay',5) || ~isempty(regexp(L,' corner$','once')), continue; end
        if strncmp(L,'WARNING',7), S(c).warn{end+1} = L; continue; end
        if strncmp(L,'Errors occurred',15), S(c).fail = true; continue; end
        kv = regexp(L, '^([A-Za-z ._]+)\t([-+0-9.eE]+)$', 'tokens');
        if ~isempty(kv)
            S(c).metrics.(matlab.lang.makeValidName(strtrim(kv{1}{1}))) = str2double(kv{1}{2});
            continue;
        end
        nums = sscanf(L, '%g\t%d');
        if numel(nums)==2, S(c).trans(end+1,:) = nums(:)'; end
    end
    ll = strsplit(fileread(fullfile(simdir, sprintf('log_%s.txt', corners{c}))), '\n');
    for ii = 1:numel(ll)
        L = strtrim(ll{ii});
        if isempty(L) || strncmp(L,'Delay',5) || ~isempty(regexp(L,' corner$','once')), continue; end
        nums = sscanf(L, '%g\t%d\t%g');
        if numel(nums)==3, S(c).runs(end+1,:) = nums(:)'; end
    end
end
end
function v = getmet(s, f)
if isfield(s.metrics, f), v = s.metrics.(f); else, v = NaN; end
end
function s = ternStr(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
