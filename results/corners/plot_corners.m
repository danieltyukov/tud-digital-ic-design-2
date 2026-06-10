% Corner-sweep analysis for TB_TDC (2-D Vernier TDC, vernier2d/tdc_core).
% Parses results_tdc_therm.csv (course format) + log_tdc_therm.txt and renders:
%   staircase_all_corners.png, dnl_per_corner.png, inl_per_corner.png,
%   power_vs_delay.png, corner_summary.csv/txt
% into the repo results/corners/ folder.

outdir = fullfile(getenv('HOME'), 'tud-digital-ic-design-2', 'results', 'corners');
if ~exist(outdir, 'dir'), mkdir(outdir); end
simdir = fullfile(getenv('HOME'), 'sims', 'tdc_corners');

%% ---- parse results CSV (corner blocks) ----
lines = strsplit(fileread(fullfile(simdir, 'results_tdc_therm.csv')), '\n');
corners = {}; C = struct([]); cur = 0;
for ii = 1:numel(lines)
    L = strtrim(lines{ii});
    if isempty(L), continue; end
    tok = regexp(L, '^(\w+) corner$', 'tokens');
    if ~isempty(tok)
        cur = cur + 1;
        corners{cur} = tok{1}{1}; %#ok<*SAGROW>
        C(cur).name = tok{1}{1};
        C(cur).trans = []; C(cur).warn = {}; C(cur).fail = false;
        C(cur).metrics = struct();
        continue;
    end
    if cur == 0 || strncmp(L, 'Delay', 5), continue; end
    if strncmp(L, 'WARNING', 7), C(cur).warn{end+1} = L; continue; end
    if strncmp(L, 'Errors occurred', 15), C(cur).fail = true; continue; end
    kv = regexp(L, '^([A-Za-z ._]+)\t([-+0-9.eE]+)$', 'tokens');
    if ~isempty(kv)
        key = matlab.lang.makeValidName(strtrim(kv{1}{1}));
        C(cur).metrics.(key) = str2double(kv{1}{2});
        continue;
    end
    nums = sscanf(L, '%g\t%d');
    if numel(nums) == 2
        C(cur).trans(end+1, :) = nums(:)';
    end
end

%% ---- parse energy log ----
loglines = strsplit(fileread(fullfile(simdir, 'log_tdc_therm.txt')), '\n');
cur = 0;
for ii = 1:numel(loglines)
    L = strtrim(loglines{ii});
    if isempty(L), continue; end
    tok = regexp(L, '^(\w+) corner$', 'tokens');
    if ~isempty(tok)
        cur = find(strcmp(corners, tok{1}{1}), 1);
        C(cur).runs = [];
        continue;
    end
    if cur == 0 || strncmp(L, 'Delay', 5), continue; end
    nums = sscanf(L, '%g\t%d\t%g');
    if numel(nums) == 3, C(cur).runs(end+1, :) = nums(:)'; end
end

nC = numel(C);
cols = lines2cols(nC);

%% ---- Plot 1: transfer staircases ----
fig = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    if isempty(C(c).runs), continue; end
    stairs(C(c).runs(:,1)*1e12, C(c).runs(:,2), 'LineWidth', 1.3, 'Color', cols(c,:));
end
xlabel('input delay (ps)'); ylabel('output code');
title('TDC transfer curve per process corner'); legend(corners, 'Location','southeast');
print(fig, fullfile(outdir, 'staircase_all_corners.png'), '-dpng', '-r150');

%% ---- DNL / INL per corner from transition delays ----
fig2 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
fig3 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    tr = C(c).trans;
    if size(tr,1) < 3, continue; end
    d = tr(:,1); code = tr(:,2);
    steps = diff(d);                          % delay per code step
    res = mean(steps);
    C(c).res_ps = res*1e12;
    dnl = steps/res - 1;
    inl = (d - d(1) - (code - code(1))*res)/res;
    figure(fig2); plot(code(2:end), dnl, '.-', 'LineWidth', 1.2, 'Color', cols(c,:));
    figure(fig3); plot(code, inl, '.-', 'LineWidth', 1.2, 'Color', cols(c,:));
    C(c).dnl_max = max(abs(dnl)); C(c).inl_max = max(abs(inl));
end
figure(fig2); xlabel('output code'); ylabel('DNL (LSB)');
yline(-1,'r--','missing-code limit'); title('DNL per process corner');
legend(corners, 'Location','best');
print(fig2, fullfile(outdir, 'dnl_per_corner.png'), '-dpng', '-r150');
figure(fig3); xlabel('output code'); ylabel('INL (LSB)');
title('INL per process corner'); legend(corners, 'Location','best');
print(fig3, fullfile(outdir, 'inl_per_corner.png'), '-dpng', '-r150');

%% ---- Power / energy vs delay ----
fig4 = figure('Visible','off','Position',[0 0 980 640]); hold on; grid on;
for c = 1:nC
    if isempty(C(c).runs), continue; end
    plot(C(c).runs(:,1)*1e12, C(c).runs(:,3)*1e12, '.-', 'LineWidth', 1.1, 'Color', cols(c,:));
end
xlabel('input delay (ps)'); ylabel('energy per conversion (pJ)');
title('Conversion energy vs input delay, per corner'); legend(corners, 'Location','best');
print(fig4, fullfile(outdir, 'power_vs_delay.png'), '-dpng', '-r150');

%% ---- summary table ----
fid = fopen(fullfile(outdir, 'corner_summary.txt'), 'w');
fprintf(fid, 'TB_TDC 5-corner sweep summary (27 C, 1.8 V)\n');
fprintf(fid, '%-6s %-6s %-10s %-9s %-9s %-9s %-12s %-8s %-12s %s\n', ...
    'corner','pass','LSB(ps)','DNLmax','INLmax','offset(ps)','E/conv(pJ)','ENOB','FoM(J)','warnings');
for c = 1:nC
    m = C(c).metrics;
    g = @(f, s) ternary(isfield(m,f), s, NaN);
    lsb   = g('Resolution',  getfieldor(m,'Resolution',NaN)*1e12);
    offs  = g('TDCOffset',   getfieldor(m,'TDCOffset',NaN)*1e12);
    epc   = g('AverageEnergy', getfieldor(m,'AverageEnergy',NaN)*1e12);
    enob  = getfieldor(m,'ENOB',NaN);
    fom   = getfieldor(m,'FoM',NaN);
    fprintf(fid, '%-6s %-6s %-10.3f %-9.3f %-9.3f %-9.2f %-12.4f %-8.3f %-12.3e %d\n', ...
        C(c).name, ternStr(~C(c).fail), lsb, ...
        getfieldor(C(c),'dnl_max',NaN), getfieldor(C(c),'inl_max',NaN), ...
        offs, epc, enob, fom, numel(C(c).warn));
    for w = 1:numel(C(c).warn), fprintf(fid, '    %s: %s\n', C(c).name, C(c).warn{w}); end
end
fclose(fid);

copyfile(fullfile(simdir, 'results_tdc_therm.csv'), outdir);
copyfile(fullfile(simdir, 'log_tdc_therm.txt'), outdir);
type(fullfile(outdir, 'corner_summary.txt'));
disp('CORNER_PLOTS_DONE');

function out = ternary(cond, a, b)
if cond, out = a; else, out = b; end
end
function s = ternStr(tf)
if tf, s = 'PASS'; else, s = 'FAIL'; end
end
function v = getfieldor(s, f, dflt)
if isfield(s, f), v = s.(f); else, v = dflt; end
end
function c = lines2cols(n)
base = lines(max(n,7)); c = base(1:n, :);
end
