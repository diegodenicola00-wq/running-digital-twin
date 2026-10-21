%% MAIN_01_PIPELINE  Phase 1: FIT files -> per-activity table -> daily load
%
% Before running:
%   1. put the .fit files from the Garmin export in data/raw/fit/
%   2. put FitCSVTool.jar (Garmin FIT SDK) in tools/
%
% Outputs (data/processed/, not committed):
%   activities.mat   A    table, one row per run + raw 1 Hz records
%   daily_load.mat   D    timetable, one row per day (input w[k] of the model)

clear; clc;
startup_project;
cfg = config();

%% 1. FIT -> CSV (only new files are converted)
convert_fit_to_csv(cfg);

%% 2. Parse every CSV, keep runs only, compute TRIMP
files = dir(fullfile(cfg.paths.csv, '*.csv'));
rows  = {};
recs  = {};

fprintf('Parsing %d files...\n', numel(files));
for i = 1:numel(files)
    act = read_fit_csv(fullfile(files(i).folder, files(i).name));

    isRun = any(strcmpi(act.sport, ["running", "1"]));
    if ~isRun || height(act.rec) < 60, continue; end

    r = act.rec;
    tStart = r.t(1);
    tStart.TimeZone = cfg.athlete.timezone;          % local time
    day = dateshift(tStart, 'start', 'day');
    day.TimeZone = '';                               % naive local date

    [trimp, info] = trimp_banister(r.t, r.hr, cfg);

    % start position: median of the first valid GPS fixes (NaN for treadmill)
    iPos = find(~isnan(r.lat) & ~isnan(r.lon), 30);
    lat0 = median(r.lat(iPos));  lon0 = median(r.lon(iPos));

    rows(end+1, :) = {act.file, tStart, day, info.duration/60, ...
        max(r.dist, [], 'omitnan')/1000, mean(r.hr, 'omitnan'), ...
        max(r.hr, [], 'omitnan'), trimp, info.validFraction, ...
        lat0, lon0, median(r.alt, 'omitnan')};                   %#ok<SAGROW>
    recs{end+1, 1} = r;                                         %#ok<SAGROW>
end

if isempty(rows)
    error(['No runs found. Put the .fit files from Garmin in:\n  %s\n', ...
           'then run main_01_pipeline again.'], cfg.paths.fit);
end

A = cell2table(rows, 'VariableNames', {'file','start','day','dur_min', ...
    'dist_km','hr_avg','hr_max','trimp','hr_valid','lat','lon','alt_m'});
A.rec = recs;
A = sortrows(A, 'start');

% Remove duplicates: the same activity can appear twice (e.g. exported by
% hand AND contained in the account export, under different file names).
[~, iu] = unique(A.start, 'stable');
nDup = height(A) - numel(iu);
if nDup > 0
    fprintf('%d duplicate activities removed (same start time).\n', nDup);
end
A = A(iu, :);
A = A(A.day >= cfg.dates.dataStart, :);

fprintf('%d runs from %s to %s\n', height(A), ...
    datestr(A.day(1), 'yyyy-mm-dd'), datestr(A.day(end), 'yyyy-mm-dd'));

%% 3. Data-quality check: optical-HR dropouts
bad = A(A.hr_valid < 0.9, {'day','dist_km','hr_avg','hr_valid'});
if ~isempty(bad)
    fprintf('\n%d runs with <90%% usable HR (TRIMP underestimated):\n', height(bad));
    disp(bad);
end

%% 4. Daily load on a continuous grid
dayEnd = max(A.day(end), dateshift(datetime('today'), 'start', 'day'));
D = daily_load(A, cfg.dates.dataStart, dayEnd);

save(fullfile(cfg.paths.processed, 'activities.mat'), 'A');
save(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');

%% 5. Sanity-check figure: daily TRIMP + fitness/fatigue proxies
% First-order filters with tau = 42 d and 7 d (the classic CTL/ATL).
% These are NOT the identified model yet: just a first look at the input.
ewma = @(x, tau) filter(1 - exp(-1/tau), [1, -exp(-1/tau)], x);
ctl  = ewma(D.w, 42);
atl  = ewma(D.w, 7);

fig = figure('Name', 'Daily training load', 'Position', [100 100 1000 500]);
yyaxis left
bar(D.day, D.w, 1, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none');
ylabel('daily TRIMP');
yyaxis right
plot(D.day, ctl, 'LineWidth', 2); hold on
plot(D.day, atl, '--', 'LineWidth', 1.5);
ylabel('EWMA of TRIMP');
xline(cfg.dates.planStart, ':', 'plan start');
xline(cfg.dates.race10k,   ':', '10 km race');
xline(cfg.dates.raceHalf,  ':', 'half marathon');
legend({'daily TRIMP', 'fitness proxy (\tau = 42 d)', ...
        'fatigue proxy (\tau = 7 d)'}, 'Location', 'northwest');
title('Training input w[k]'); grid on

exportgraphics(fig, fullfile(cfg.paths.results, 'fig01_daily_load.png'), ...
    'Resolution', 200);
fprintf('\nSaved: data/processed/*.mat, results/fig01_daily_load.png\n');
