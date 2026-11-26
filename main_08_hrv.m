%% MAIN_08_HRV  Phase 2: morning HRV from the HRM 600 chest strap (HRV Logger)
%
% Input:  data/raw/hrv/*_RR_*.csv  (HRV Logger export; one morning session per day)
% Rules:  cfg.hrv (fixed on 23 Nov 2026, before the series is collected)
%  - morning session = start between cfg.hrv.morning(1) and (2) o'clock;
%    if a day has more than one, the last one is kept (a repeated measurement);
%  - indices from hrv_session.m; the trend uses ln(rMSSD) and its 7-day mean;
%  - context notes (data/raw/hrv/notes.csv, rule of 26 Nov 2026): days with a tag
%    stay in the main series; the only sensitivity check excludes the tags in
%    cfg.hrv.sensExclude (illness is outside the training -> fatigue model).
%
% Outputs: results/hrv_morning.csv, results/fig12_hrv.png

clear; clc;
startup_project;
cfg = config();
H = cfg.hrv;

files = dir(fullfile(H.dir, '*_RR_*.csv'));
if isempty(files), error('No HRV Logger RR files in %s', H.dir); end

rows = [];
for i = 1:numel(files)
    f = fullfile(files(i).folder, files(i).name);
    S = read_hrvlogger_rr(f);
    hh = hour(S.start) + minute(S.start) / 60;
    if hh < H.morning(1) || hh >= H.morning(2)
        fprintf('Skipped (not a morning session): %s\n', files(i).name);
        continue
    end
    M = hrv_session(S, H);
    M.file = string(files(i).name);
    rows = [rows; M]; %#ok<AGROW>
end
if isempty(rows), error('No morning sessions found.'); end

T = struct2table(rows);
T.day = dateshift(T.start, 'start', 'day');
T = sortrows(T, 'start');
[~, last] = unique(T.day, 'last');                       % last session of each day
T = T(last, :);

% context notes
N = read_hrv_notes(fullfile(H.dir, H.notesFile));
T.tag = strings(height(T), 1);  T.note = strings(height(T), 1);
[isN, loc] = ismember(T.day, N.day);
T.tag(isN) = N.tag(loc(isN));  T.note(isN) = N.note(loc(isN));
noMatch = setdiff(N.day, T.day);
for i = 1:numel(noMatch)
    fprintf('Note of %s has no morning session.\n', datestr(noMatch(i), 'dd-mmm-yyyy'));
end
T.sens = T.valid;                                         % sensitivity set
for k = 1:numel(H.sensExclude)
    T.sens = T.sens & ~contains(T.tag, H.sensExclude(k));
end

% 7-day rolling mean of ln rMSSD (calendar window): main series and sensitivity
T.ln7 = nan(height(T), 1);  T.ln7sens = nan(height(T), 1);
for i = 1:height(T)
    w = T.day > T.day(i) - days(7) & T.day <= T.day(i);
    T.ln7(i)     = mean(T.lnRmssd(w & T.valid));
    T.ln7sens(i) = mean(T.lnRmssd(w & T.sens));
end

out = T(:, {'day','start','dur','nBeats','repeats','artFrac','hr','rmssd','lnRmssd','sdnn', ...
    'ln7','ln7sens','valid','tag','note','file'});
writetable(out, fullfile(cfg.paths.results, 'hrv_morning.csv'));

fprintf('\n  day          start  HR    rMSSD  lnRMSSD  ln7    art%%  valid  tag\n');
for i = 1:height(T)
    fprintf('  %s  %s  %4.1f  %6.1f  %6.2f  %5.2f  %4.1f   %d     %s\n', datestr(T.day(i), 'dd-mmm-yyyy'), ...
        datestr(T.start(i), 'HH:MM'), T.hr(i), T.rmssd(i), T.lnRmssd(i), T.ln7(i), ...
        100 * T.artFrac(i), T.valid(i), T.tag(i));
end
fprintf('Repeated beats removed in the last session: %d\n', T.repeats(end));

fig12 = figure('Name', 'Morning HRV', 'Position', [100 100 900 380]);
v = T.valid;
plot(T.day(v), T.lnRmssd(v), 'o', 'MarkerFaceColor', [0.6 0.75 0.9]); hold on
plot(T.day, T.ln7, '-', 'LineWidth', 1.8);
if any(~v), plot(T.day(~v), T.lnRmssd(~v), 'x', 'Color', [0.6 0.6 0.6]); end
iT = find(T.tag ~= "");
for i = iT'
    text(T.day(i), T.lnRmssd(i), "  " + T.tag(i), 'FontSize', 8, 'Rotation', 90, ...
        'Interpreter', 'none');                           % keep the "_" in the tags
end
xlim([T.day(1) - days(1), T.day(end) + days(1)]);         % room for the labels at the ends
yl = ylim;  ylim([yl(1), yl(2) + 0.1 * diff(yl)]);
ylabel('ln rMSSD [ln ms]');  grid on
legend({'daily', '7-day mean'}, 'Location', 'best');
title('Morning HRV (HRM 600, supine, 5 min)');
exportgraphics(fig12, fullfile(cfg.paths.results, 'fig12_hrv.png'), 'Resolution', 200);

fprintf('\nSaved: results/hrv_morning.csv, results/fig12_hrv.png\n');
