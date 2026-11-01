%% MAIN_06_PREDICTION  Step 6: pre-registered prediction of the half marathon
%
% The METHOD below is committed before the race; the final numbers are produced by
% running this script after the last training run (19-20 Nov 2026) and committed
% before the start (22 Nov 2026, 8:45). Nothing is tuned after the race.
%
% Needs, up to date: main_01_pipeline, main_02_performance, main_03_identification,
% main_04_kalman (the dynamic EF and the filter parameters of Step 4).
%
% Method (fixed in advance):
%   T_half = T_10k * (d_half / d_10k)^e / (1 + g)
%
%   1. Anchor: 10 km race of 27 Sep 2026, 40:59 (the only race of the period).
%   2. Distance: Riegel's formula, exponent e uniform in [1.04, 1.08], central 1.06.
%   3. Fitness change since the anchor: g = relative change of the aerobic baseline b
%      of the Kalman filter (Step 4) from 27 Sep to the last run, estimated with a
%      fixed-point smoother (kf_baseline_change.m), with its standard deviation.
%      Assumption: at the same HR, speed scales with the efficiency (EF = v / net HR).
%   4. Interval: 10th-90th percentile of T_half by Monte Carlo over e and g.
%   5. Freshness (taper) is NOT used in the number: both races follow a reduction of
%      the load; the Banister model (9 scenarios of Step 5) only reports whether form
%      on race day is higher or lower than on the anchor day.
%
% Outputs: results/prediction_<yyyymmdd>.txt, results/fig10_prediction.png (+ PDF)

clear; clc;
startup_project;
cfg = config();
Q = cfg.pred;
raceDay = cfg.dates.raceHalf;
fmt = @(s) char(duration(0, 0, round(s), 'Format', 'hh:mm:ss'));

S = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');            D = S.D;
S = load(fullfile(cfg.paths.processed, 'identification.mat'), 'Td');       Td = S.Td;
S = load(fullfile(cfg.paths.processed, 'kalman.mat'), 'best');             best = S.best;

w = D.w;  N = numel(w);
dayIx = @(d) days(d - D.day(1)) + 1;
lastRun = D.day(find(D.w > 0, 1, 'last'));

%% 1-2. Anchor and Riegel
T10 = Q.anchorTime;
ratio = Q.raceDist / Q.anchorDist;
eList = [Q.eRange(1), Q.eCentral, Q.eRange(2)];
fprintf('Anchor: %g km on %s in %s.  Last run in the data: %s.\n\n', Q.anchorDist, ...
    datestr(Q.anchorDate, 'dd-mmm-yyyy'), fmt(T10), datestr(lastRun, 'dd-mmm-yyyy'));
fprintf('Riegel only (no fitness change):\n');
for e = eList
    fprintf('  e = %.2f  ->  %s  (%s per km)\n', e, fmt(T10*ratio^e), fmt(T10*ratio^e / Q.raceDist));
end

%% 3. Fitness change since the anchor (Kalman filter, fixed-point smoother)
[g0, mDay] = findgroups(Td.day);
yd = splitapply(@mean, Td.ef_dyn, g0);
nd = splitapply(@numel, Td.ef_dyn, g0);
km = dayIx(mDay);  ok = km >= 1 & km <= N;
R = kf_baseline_change(w, km(ok), yd(ok), nd(ok), best, dayIx(Q.anchorDate));
fprintf('\nAerobic baseline (Kalman, Step 4): %.3f on %s (smoothed) -> %.3f on %s\n', ...
    R.bFix, datestr(Q.anchorDate, 'dd-mmm'), R.bEnd, datestr(D.day(R.kLast), 'dd-mmm'));
fprintf('  change g = %+.1f %% +- %.1f %% (1 sd)\n', 100*R.g, 100*R.sdg);

%% 4. Prediction and interval (Monte Carlo)
rng(Q.seed);
eMC = Q.eRange(1) + diff(Q.eRange) * rand(Q.nMC, 1);
gMC = R.g + R.sdg * randn(Q.nMC, 1);
TMC = T10 * ratio.^eMC ./ (1 + gMC);
Tc  = T10 * ratio^Q.eCentral / (1 + R.g);
Ts  = sort(TMC);
TI  = Ts(round(Q.interval/100 * Q.nMC))';          % percentiles (no toolbox needed)
fprintf('\n============ PRE-REGISTERED PREDICTION, half marathon %s ============\n', ...
    datestr(raceDay, 'dd-mmm-yyyy'));
fprintf('  central: %s  (%s per km)\n', fmt(Tc), fmt(Tc / Q.raceDist));
fprintf('  %d%% interval: %s - %s\n', diff(Q.interval), fmt(TI(1)), fmt(TI(2)));
fprintf('=====================================================================\n');

%% 5. Freshness check with the Banister model (not used in the number)
wAll = w;                                             % load up to the last day of D
dAll = D.day;
athFile = fullfile(cfg.paths.results, 'athlete_plan.csv');
if isfile(athFile) && dAll(end) < raceDay - 1
    opts = detectImportOptions(athFile, 'TextType', 'string');
    opts = setvartype(opts, 'date', 'datetime');
    opts = setvaropts(opts, 'date', 'InputFormat', 'yyyy-MM-dd');
    Ath = readtable(athFile, opts);
    Hf = (dAll(end) + caldays(1) : caldays(1) : raceDay - caldays(1))';
    trimp = Ath.km_easy*cfg.mpc.rate.easy + Ath.km_hm*cfg.mpc.rate.hm + Ath.km_threshold*cfg.mpc.rate.threshold;
    [tf, loc] = ismember(Ath.date, Hf);
    wAll = [wAll; accumarray(loc(tf), trimp(tf), [numel(Hf), 1])];
    dAll = [dAll; Hf];
    fprintf('\nFreshness check: load up to %s, then your plan (athlete_plan.csv).\n', datestr(D.day(end), 'dd-mmm'));
else
    fprintf('\nFreshness check: load up to %s (no plan added).\n', datestr(dAll(end), 'dd-mmm'));
end
iA = find(dAll == Q.anchorDate);  iR = numel(dAll) + 1;   % race day = day after the last one
[K2, T2] = meshgrid(cfg.mpc.scenK2, cfg.mpc.scenTau2);
sc = [K2(:), T2(:)];
better = 0;
for s = 1:size(sc, 1)
    x1 = [0; filter(1, [1, -exp(-1/cfg.mpc.tau1)], wAll)];
    x2 = [0; filter(1, [1, -exp(-1/sc(s, 2))], wAll)];
    p = cfg.mpc.k1*x1 - sc(s, 1)*x2;
    fprintf('  k2/k1 = %.1f, tau2 = %2g d:  fitness %+5.0f, fatigue %+5.0f, form %+5.0f (race day - anchor day)\n', ...
        sc(s, 1), sc(s, 2), x1(iR) - x1(iA), x2(iR) - x2(iA), p(iR) - p(iA));
    better = better + (p(iR) > p(iA));
end
fprintf('  form on race day higher than on the anchor day in %d of %d scenarios\n', better, size(sc, 1));

%% Save the prediction (to be committed BEFORE the race)
stamp = datestr(datetime('now'), 'yyyymmdd');
fid = fopen(fullfile(cfg.paths.results, ['prediction_' stamp '.txt']), 'w');
fprintf(fid, 'Pre-registered prediction, half marathon %s\n', datestr(raceDay, 'dd-mmm-yyyy'));
fprintf(fid, 'Produced: %s, data up to %s\n', datestr(datetime('now'), 'dd-mmm-yyyy HH:MM'), datestr(lastRun, 'dd-mmm-yyyy'));
fprintf(fid, 'Anchor: %g km, %s, %s\n', Q.anchorDist, datestr(Q.anchorDate, 'dd-mmm-yyyy'), fmt(T10));
fprintf(fid, 'Riegel e = %.2f / %.2f / %.2f: %s / %s / %s\n', eList, fmt(T10*ratio^eList(1)), ...
    fmt(T10*ratio^eList(2)), fmt(T10*ratio^eList(3)));
fprintf(fid, 'Baseline change since anchor: g = %+.2f %% +- %.2f %%\n', 100*R.g, 100*R.sdg);
fprintf(fid, 'CENTRAL: %s (%s per km)\n', fmt(Tc), fmt(Tc / Q.raceDist));
fprintf(fid, '%d%% INTERVAL: %s - %s\n', diff(Q.interval), fmt(TI(1)), fmt(TI(2)));
fprintf(fid, 'Freshness: form higher on race day in %d of %d model scenarios (not used)\n', better, size(sc, 1));
fclose(fid);

%% Figure
fig10 = figure('Name', 'Prediction', 'Position', [100 100 900 420]); hold on
histogram(minutes(seconds(TMC)), 80, 'Normalization', 'pdf', 'FaceColor', [0.6 0.75 0.9], ...
    'EdgeColor', 'none', 'DisplayName', 'Monte Carlo (e, g)');
xline(minutes(seconds(Tc)), '-', sprintf('central %s', fmt(Tc)), 'LineWidth', 2, 'Color', [0 0.45 0.74], ...
    'HandleVisibility', 'off');
xline(minutes(seconds(TI)), '--', {sprintf('%d%%', Q.interval(1)), sprintf('%d%%', Q.interval(2))}, ...
    'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
xlabel('half-marathon time [min]'); ylabel('density'); grid on
title(sprintf('Pre-registered prediction: %s (%d%% interval %s - %s)', fmt(Tc), diff(Q.interval), ...
    fmt(TI(1)), fmt(TI(2))));
exportgraphics(fig10, fullfile(cfg.paths.results, 'fig10_prediction.png'), 'Resolution', 200);
export_report_figure(fig10, 'fig10_prediction', cfg);

fprintf('\nSaved: results/prediction_%s.txt, results/fig10_prediction.png\n', stamp);
