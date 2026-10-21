%% MAIN_02_PERFORMANCE  Step 2: aerobic-efficiency index as the performance measure p[k]
%
% Needs the output of main_01_pipeline (data/processed/activities.mat, daily_load.mat).
%
% For every run: efficiency_index -> EF [m per net heartbeat] + quality metrics.
% Runs used as performance measurements: easy (HR reserve <= cfg.perf.maxHRR)
% and steady (low pace variability, mostly steady samples). Intervals and races
% are excluded: HR lags behind short efforts and inflates EF.
%
% Outputs:
%   data/processed/performance.mat   E (all runs + metrics), P (selected runs: day, ef)
%   results/fig02_efficiency.png

clear; clc;
startup_project;
cfg = config();

S1 = load(fullfile(cfg.paths.processed, 'activities.mat'), 'A');
S2 = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');
A = S1.A;  D = S2.D;

%% 1. Efficiency metrics for every run
n = height(A);
ef = nan(n,1); gap = ef; hr = ef; hrr = ef; cv = ef; stf = ef; win = ef;
for i = 1:n
    m = efficiency_index(A.rec{i}, cfg);
    ef(i) = m.ef;  gap(i) = m.gap_kmh;  hr(i) = m.hr;  hrr(i) = m.hrr;
    cv(i) = m.cv;  stf(i) = m.steadyFrac;  win(i) = m.winMin;
end
E = table(A.day, A.dist_km, ef, gap, hr, hrr, cv, stf, win, ...
    'VariableNames', {'day','dist_km','ef','gap_kmh','hr','hrr','cv','steadyFrac','winMin'});

%% 2. Selection: easy, steady runs
E.use = ~isnan(E.ef) & E.cv <= cfg.perf.maxCV ...
      & E.steadyFrac >= cfg.perf.minSteady & E.hrr <= cfg.perf.maxHRR;

fprintf('%d runs, %d with a valid window, %d selected as easy+steady.\n', ...
    n, nnz(~isnan(E.ef)), nnz(E.use));
fprintf('Excluded: %d too short, %d unsteady (CV/steady share), %d too intense.\n', ...
    nnz(isnan(E.ef)), ...
    nnz(~isnan(E.ef) & (E.cv > cfg.perf.maxCV | E.steadyFrac < cfg.perf.minSteady)), ...
    nnz(~isnan(E.ef) & E.cv <= cfg.perf.maxCV & E.steadyFrac >= cfg.perf.minSteady ...
        & E.hrr > cfg.perf.maxHRR));

P = E(E.use, {'day','ef'});

%% 3. Measurement noise (first estimate)
% Pairs of selected runs at most 3 days apart: real fitness can hardly change
% in 3 days, so their difference is mostly measurement noise.
% sigma = std(diff)/sqrt(2)  (difference of two independent noisy measures)
dd  = days(diff(P.day));
dEF = diff(P.ef);
near = dd <= 3;
if nnz(near) >= 3
    sigma = std(dEF(near)) / sqrt(2);
    fprintf('Noise estimate: sigma = %.3f m/beat (%.1f%% of mean EF), from %d pairs <= 3 days apart.\n', ...
        sigma, 100*sigma/mean(P.ef), nnz(near));
else
    sigma = NaN;
    fprintf('Not enough close pairs for a noise estimate.\n');
end

save(fullfile(cfg.paths.processed, 'performance.mat'), 'E', 'P', 'sigma');

%% 4. Figure: EF over time vs fitness proxy
ewma = @(x, tau) filter(1 - exp(-1/tau), [1, -exp(-1/tau)], x);
ctl  = ewma(D.w, 42);

% rest periods: gaps of >= 7 days between consecutive runs
gapIdx = find(days(diff(A.day)) >= 7);

fig = figure('Name', 'Aerobic efficiency', 'Position', [100 100 1000 650]);
tl  = tiledlayout(2, 1, 'TileSpacing', 'compact');

ax1 = nexttile; hold on
for g = gapIdx'
    xline([A.day(g) A.day(g+1)], '-', 'Color', [0.75 0.75 0.75], ...
        'LineWidth', 1, 'HandleVisibility', 'off');
end
plot(E.day(~E.use), E.ef(~E.use), 'o', 'Color', [0.6 0.6 0.6], ...
    'DisplayName', 'excluded (intervals, races, unsteady)');
plot(P.day, P.ef, 'o', 'MarkerFaceColor', [0 0.45 0.74], ...
    'MarkerEdgeColor', 'none', 'DisplayName', 'easy + steady runs');
if height(P) >= 5
    plot(P.day, movmedian(P.ef, 5), '-', 'LineWidth', 2, ...
        'Color', [0 0.45 0.74], 'DisplayName', 'running median (5 runs)');
end
xline(cfg.dates.planStart, ':', 'plan start', 'HandleVisibility', 'off');
xline(cfg.dates.race10k,   ':', '10 km race', 'HandleVisibility', 'off');
valid = ~isnan(E.ef);
ylim([min(E.ef(valid))*0.95, max(E.ef(valid))*1.05]);
ylabel('EF [m per net beat]'); grid on
legend('Location', 'northwest');
title('Aerobic efficiency (grey lines: start/end of rest periods >= 7 days)');

ax2 = nexttile;
plot(D.day, ctl, 'LineWidth', 1.5, 'Color', [0.85 0.33 0.10]);
ylabel('fitness proxy (\tau = 42 d)'); grid on
title('Training load, EWMA (literature time constant, not identified)');

linkaxes([ax1 ax2], 'x');
xlim([cfg.dates.dataStart, max(D.day)]);

exportgraphics(fig, fullfile(cfg.paths.results, 'fig02_efficiency.png'), 'Resolution', 200);
fprintf('Saved: data/processed/performance.mat, results/fig02_efficiency.png\n');
