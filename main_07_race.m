%% MAIN_07_RACE  Step 6 (after the race): race analysis and registered checks
%
% Needs, up to date (with the race file): main_01_pipeline, main_02_performance,
% main_03_identification, main_04_kalman. The pre-registered prediction itself is
% NOT recomputed here: it is in results/prediction_20261120.txt (commit 580331d).
%
%  1. The race from the watch: splits per km, pacing, heart rate and its drift.
%  2. Prediction vs result, and the Riegel exponent implied by the result.
%  3. Sensitivity of the fitness term g, as registered on 20 Nov before the race:
%     all runs / Milan runs only / measurements before the taper / both.
%     Same method and parameters as main_06; only the measurements used change.
%
% Outputs: results/race_analysis.txt, results/fig11_race.png (+ PDF)

clear; clc;
startup_project;
cfg = config();
Q = cfg.pred;  RC = cfg.race;
raceDay = cfg.dates.raceHalf;
fmt = @(s) char(duration(0, 0, round(s), 'Format', 'hh:mm:ss'));
pace = @(s) char(duration(0, 0, round(s), 'Format', 'mm:ss'));

S = load(fullfile(cfg.paths.processed, 'activities.mat'), 'A');        A = S.A;
S = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');        D = S.D;
S = load(fullfile(cfg.paths.processed, 'identification.mat'), 'Td');   Td = S.Td;
S = load(fullfile(cfg.paths.processed, 'kalman.mat'), 'best');         best = S.best;

%% 1. The race from the watch
iR = find(A.day == raceDay);
if isempty(iR)
    error('No run on %s in the data: add the race FIT file and run main_01_pipeline.', ...
        datestr(raceDay, 'dd-mmm-yyyy'));
end
[~, k] = max(A.dist_km(iR));  iR = iR(k);
r = A.rec{iR};
ts = seconds(r.t - r.t(1));
ok = ~isnan(r.dist);
[dU, iu] = unique(r.dist(ok));  tU = ts(ok);  tU = tU(iu);
nKm = floor(dU(end) / 1000);
tKm = interp1(dU, tU, (0:nKm)' * 1000, 'linear', 'extrap');  % time at every km mark
tKm(1) = max(tKm(1), 0);           % first GPS distance can be > 0: start of the race at t = 0
split = diff(tKm);
hrKm = nan(nKm, 1);
for q = 1:nKm
    m = ts >= tKm(q) & ts < tKm(q+1);
    hrKm(q) = mean(r.hr(m), 'omitnan');
end
half = floor(nKm / 2);
t1 = sum(split(1:half));  t2 = sum(split(half+1:2*half));
hr1 = mean(hrKm(1:half));  hr2 = mean(hrKm(half+1:2*half));
v1 = half*1000 / t1;  v2 = half*1000 / t2;
ef1 = v1*60 / (hr1 - cfg.athlete.HRrest);  ef2 = v2*60 / (hr2 - cfg.athlete.HRrest);

fprintf('Race of %s: %.2f km (watch), %s (watch time), mean HR %.0f, max %.0f bpm\n', ...
    datestr(raceDay, 'dd-mmm-yyyy'), A.dist_km(iR), fmt(ts(end)), A.hr_avg(iR), A.hr_max(iR));
fprintf('\n  km   split   HR\n');
for q = 1:nKm
    fprintf('  %2d   %s   %3.0f\n', q, pace(split(q)), hrKm(q));
end
fprintf('\nPacing: first %d km %s, second %d km %s (%+.1f %%)\n', half, fmt(t1), half, fmt(t2), ...
    100*(t2/t1 - 1));
fprintf('HR: first half %.0f, second half %.0f bpm (drift %+.1f bpm)\n', hr1, hr2, hr2 - hr1);
fprintf('Race efficiency (m per net beat): first half %.3f, second half %.3f (%+.1f %%)\n', ...
    ef1, ef2, 100*(ef2/ef1 - 1));
fprintf('Mean HR as fraction of the HR reserve: %.2f\n', ...
    (A.hr_avg(iR) - cfg.athlete.HRrest) / (cfg.athlete.HRmax - cfg.athlete.HRrest));

%% 2. Prediction vs result
T10 = Q.anchorTime;  ratio = Q.raceDist / Q.anchorDist;
Tact = RC.chipTime;
fprintf('\nOfficial chip time: %s (%s per km)\n', fmt(Tact), pace(Tact / Q.raceDist));
eImpl0 = log(Tact / T10) / log(ratio);
fprintf('Riegel exponent implied by the result: %.3f (no fitness change)\n', eImpl0);

%% 3. Registered sensitivity checks on g
w = D.w;
dayIx = @(d) days(d - D.day(1)) + 1;
site = strings(height(Td), 1);                      % place of each measurement
for q = 1:height(Td)
    j = find(A.day == Td.day(q) & ~isnan(A.lat), 1);
    if ~isempty(j), site(q) = string(site_label(A.lat(j), A.lon(j), cfg)); end
end
cases = {'all runs (as pre-registered)',  RC.predCutoff,  false
         'Milan runs only',               RC.predCutoff,  true
         'before the taper (to 8 Nov)',   RC.preTaperEnd, false
         'Milan only, before the taper',  RC.preTaperEnd, true};
fprintf('\nSensitivity of the fitness term g (method of main_06, registered on 20 Nov):\n');
fprintf('  %-32s %5s %13s %10s %10s\n', 'measurements', 'n', 'g [%]', 'central', 'error');
Res = table();
for c = 1:size(cases, 1)
    sel = Td.day <= cases{c, 2};
    if cases{c, 3}, sel = sel & site == "Milano"; end
    [g0, mDay] = findgroups(Td.day(sel));
    yd = splitapply(@mean, Td.ef_dyn(sel), g0);
    nd = splitapply(@numel, Td.ef_dyn(sel), g0);
    N  = dayIx(cases{c, 2});
    km = dayIx(mDay);  ok = km >= 1 & km <= N;
    R  = kf_baseline_change(w(1:N), km(ok), yd(ok), nd(ok), best, dayIx(Q.anchorDate));
    Tc = T10 * ratio^Q.eCentral / (1 + R.g);
    fprintf('  %-32s %5d %+6.1f +- %3.1f %10s %+9.0f s\n', cases{c, 1}, nnz(ok), 100*R.g, ...
        100*R.sdg, fmt(Tc), Tact - Tc);
    Res = [Res; table(string(cases{c, 1}), nnz(ok), R.g, R.sdg, Tc, Tact - Tc, ...
        'VariableNames', {'case', 'n', 'g', 'sd_g', 'central_s', 'error_s'})]; %#ok<AGROW>
end
fprintf('(error = actual - predicted; positive: the race was slower than predicted)\n');

%% Save
fid = fopen(fullfile(cfg.paths.results, 'race_analysis.txt'), 'w');
fprintf(fid, 'Half marathon %s: chip time %s; watch %.2f km, mean HR %.0f\n', ...
    datestr(raceDay, 'dd-mmm-yyyy'), fmt(Tact), A.dist_km(iR), A.hr_avg(iR));
fprintf(fid, 'Halves: %s / %s (%+.1f %%), HR %.0f / %.0f bpm, EF %.3f / %.3f\n', ...
    fmt(t1), fmt(t2), 100*(t2/t1 - 1), hr1, hr2, ef1, ef2);
fprintf(fid, 'Implied Riegel exponent (no fitness change): %.3f\n', eImpl0);
for c = 1:height(Res)
    fprintf(fid, '%s: n = %d, g = %+.2f %% +- %.2f %%, central %s, error %+.0f s\n', ...
        Res.case(c), Res.n(c), 100*Res.g(c), 100*Res.sd_g(c), fmt(Res.central_s(c)), Res.error_s(c));
end
fclose(fid);
save(fullfile(cfg.paths.processed, 'race.mat'), 'split', 'hrKm', 'Res', 'Tact');

%% Figure
fig11 = figure('Name', 'Race', 'Position', [100 100 1000 420]);
yyaxis left
bar(1:nKm, split / 60, 0.7, 'FaceColor', [0.6 0.75 0.9], 'EdgeColor', 'none'); hold on
yline(Tact / Q.raceDist / 60, '-', sprintf('mean %s /km', pace(Tact / Q.raceDist)), ...
    'Color', [0 0.45 0.74]);
ylabel('split [min/km]');  ylim([min(split)/60 - 0.15, max(split)/60 + 0.1]);
yyaxis right
plot(1:nKm, hrKm, 'o-', 'LineWidth', 1.5);
ylabel('mean HR [bpm]');
xlabel('km'); grid on
title(sprintf('Half marathon %s: %s (pre-registered prediction %s)', datestr(raceDay, 'dd mmm yyyy'), ...
    fmt(Tact), fmt(RC.predCentral)));
exportgraphics(fig11, fullfile(cfg.paths.results, 'fig11_race.png'), 'Resolution', 200);
export_report_figure(fig11, 'fig11_race', cfg);

fprintf('\nSaved: results/race_analysis.txt, results/fig11_race.png, data/processed/race.mat\n');
