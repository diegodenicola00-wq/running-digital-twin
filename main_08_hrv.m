%% MAIN_08_HRV  Phase 2: morning HRV from the HRM 600 chest strap (HRV Logger)
%
% Input:  data/raw/hrv/*_RR_*.csv  (HRV Logger export; one morning session per day)
% Rules:  cfg.hrv (fixed on 23 Nov 2026, before the series is collected)
%  - morning session = start between cfg.hrv.morning(1) and (2) o'clock;
%    if a day has more than one, the last one is kept (a repeated measurement);
%  - indices from hrv_session.m; the trend uses ln(rMSSD) and its 7-day mean.
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

% 7-day rolling mean of ln rMSSD over valid days (calendar window)
T.ln7 = nan(height(T), 1);
for i = 1:height(T)
    w = T.valid & T.day > T.day(i) - days(7) & T.day <= T.day(i);
    T.ln7(i) = mean(T.lnRmssd(w));
end

out = T(:, {'day','start','dur','nBeats','repeats','artFrac','hr','rmssd','lnRmssd','sdnn','ln7','valid','file'});
writetable(out, fullfile(cfg.paths.results, 'hrv_morning.csv'));

fprintf('\n  day          HR    rMSSD  lnRMSSD  art%%  valid\n');
for i = 1:height(T)
    fprintf('  %s  %4.1f  %6.1f  %6.2f  %4.1f   %d\n', datestr(T.day(i), 'dd-mmm-yyyy'), ...
        T.hr(i), T.rmssd(i), T.lnRmssd(i), 100 * T.artFrac(i), T.valid(i));
end
fprintf('Repeated beats removed in the last session: %d\n', T.repeats(end));

fig12 = figure('Name', 'Morning HRV', 'Position', [100 100 900 380]);
v = T.valid;
plot(T.day(v), T.lnRmssd(v), 'o', 'MarkerFaceColor', [0.6 0.75 0.9]); hold on
plot(T.day, T.ln7, '-', 'LineWidth', 1.8);
if any(~v), plot(T.day(~v), T.lnRmssd(~v), 'x', 'Color', [0.6 0.6 0.6]); end
ylabel('ln rMSSD [ln ms]');  grid on
legend({'daily', '7-day mean'}, 'Location', 'best');
title('Morning HRV (HRM 600, supine, 5 min)');
exportgraphics(fig12, fullfile(cfg.paths.results, 'fig12_hrv.png'), 'Resolution', 200);

fprintf('\nSaved: results/hrv_morning.csv, results/fig12_hrv.png\n');
