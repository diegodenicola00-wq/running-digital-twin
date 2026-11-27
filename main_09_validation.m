%% MAIN_09_VALIDATION  Phase 2: wrist (optical) HR of the watch vs the HRM 600 chest strap
%
% Each validation run is recorded twice: the strap sends its HR to the phone (HRV Logger,
% exported to data/raw/hrv_runs) and the watch records with its optical sensor only.
% Needs main_01_pipeline up to date (the run's FIT file in data/processed/activities.mat).
% Rules: cfg.val, fixed on 27 Nov 2026 before the comparison.
%
%  - common 1 Hz grid on absolute time (watch UTC, phone local time), no shift;
%    the first and last cfg.val.edge seconds (standing still) are excluded;
%  - "steady": watch speed (10-s mean) in cfg.val.vSteady and > 60 s after a stride;
%    "strides": from the start of each stride (speed > cfg.val.vStride) to +90 s;
%  - per segment: bias (watch - strap), SD, 95 % limits of agreement (Bland & Altman),
%    mean absolute error, % of samples within +-cfg.val.tolBpm;
%  - lag of the optical sensor: cross-correlation of the high-passed series
%    (minus a 60-s moving mean), lags +-cfg.val.maxLag s; positive = watch late;
%  - effect on the project: bias of the efficiency factor EF ~ v/(HR - HRrest) in
%    "steady" = (HRs - HRrest)/(HRw - HRrest) - 1.
%
% Outputs: results/validation_runs.csv, results/fig13_validation.png

clear; clc;
startup_project;
cfg = config();
V = cfg.val;  tz = cfg.athlete.timezone;  HRrest = cfg.athlete.HRrest;

S = load(fullfile(cfg.paths.processed, 'activities.mat'), 'A');  A = S.A;
t0 = cellfun(@(r) posixtime(r.t(1)), A.rec);            % start of every activity [s]

files = dir(fullfile(V.dir, '*_HR_*.csv'));
if isempty(files), error('No HRV Logger HR files in %s', V.dir); end

res = [];
for f = 1:numel(files)
    Hs = read_hrvlogger_hr(fullfile(files(f).folder, files(f).name), tz);
    Hs.Properties.RowTimes.TimeZone = 'UTC';

    [dt, i] = min(abs(t0 - posixtime(Hs.Properties.RowTimes(1))));
    if dt > 300
        fprintf('No watch activity within 5 min of %s: run main_01_pipeline?\n', files(f).name);
        continue
    end
    r = A.rec{i};
    W = timetable(r.t, r.hr, r.speed, 'VariableNames', {'hrw', 'v'});
    W = retime(W, 'secondly', 'linear');                % fills the 1-2 s holes of the FIT

    % common grid, standing still excluded (times as posix seconds)
    tw = posixtime(W.Properties.RowTimes);  th = posixtime(Hs.Properties.RowTimes);
    tA = max(tw(1), th(1)) + V.edge;
    tB = min(tw(end), th(end)) - V.edge;
    pg = (tA:1:tB)';
    g  = datetime(pg, 'ConvertFrom', 'posixtime', 'TimeZone', tz);
    hw = interp1(tw, W.hrw, pg);
    v  = movmean(interp1(tw, W.v, pg), V.speedWin);
    hs = interp1(th, Hs.hr, pg);                        % strap holes stay NaN
    ts = seconds(g - g(1));

    % segments
    isStr = false(size(g));  steady = false(size(g));
    on = find(diff([false; v > V.vStride]) == 1);       % start of every stride
    lastStr = -inf(size(g));
    for k = on'
        isStr(ts >= ts(k) & ts < ts(k) + V.strideWin) = true;
    end
    for k = 1:numel(g)
        p = on(on <= k);
        if ~isempty(p), lastStr(k) = ts(p(end)); end
    end
    steady = v >= V.vSteady(1) & v <= V.vSteady(2) & ~isStr & (ts - lastStr) > V.afterStride;

    % lag of the optical sensor
    ok = ~isnan(hw) & ~isnan(hs);
    a = hw - movmean(hw, V.hpWin, 'omitnan');  b = hs - movmean(hs, V.hpWin, 'omitnan');
    a(~ok) = 0;  b(~ok) = 0;
    lags = -V.maxLag:V.maxLag;  xc = nan(size(lags));
    for j = 1:numel(lags)                               % corr(hw(t + L), hs(t))
        L = lags(j);
        if L >= 0, x = a(1+L:end); y = b(1:end-L); else, x = a(1:end+L); y = b(1-L:end); end
        xc(j) = (x - mean(x))' * (y - mean(y)) / sqrt(sum((x - mean(x)).^2) * sum((y - mean(y)).^2));
    end
    [xcMax, j] = max(xc);  lag = lags(j);

    segs = {'all', ok; 'steady', ok & steady; 'strides', ok & isStr};
    for s = 1:size(segs, 1)
        m = segs{s, 2};
        e = hw(m) - hs(m);
        R.run = string(files(f).name);  R.activity = string(A.file(i));
        R.segment = string(segs{s, 1});  R.n = sum(m);
        R.hrStrap = mean(hs(m));  R.hrWatch = mean(hw(m));
        R.bias = mean(e);  R.sd = std(e);
        R.loaLow = R.bias - 1.96 * R.sd;  R.loaHigh = R.bias + 1.96 * R.sd;
        R.mae = mean(abs(e));  R.within = mean(abs(e) <= V.tolBpm);
        R.efBias = (R.hrStrap - HRrest) / (R.hrWatch - HRrest) - 1;
        R.lag = lag;  R.xcorr = xcMax;
        res = [res; R]; %#ok<AGROW>
    end

    fprintf('\n%s  (watch: %s)\n', files(f).name, A.file(i));
    fprintf('  segment   n     strap  watch  bias   SD    LoA 95%%          MAE   within%d  EF bias\n', V.tolBpm);
    for s = numel(res) - 2:numel(res)
        q = res(s);
        fprintf('  %-8s %5d  %5.1f  %5.1f  %+5.1f  %4.1f  [%+5.1f, %+5.1f]  %4.1f  %5.1f %%  %+5.1f %%\n', ...
            q.segment, q.n, q.hrStrap, q.hrWatch, q.bias, q.sd, q.loaLow, q.loaHigh, q.mae, ...
            100 * q.within, 100 * q.efBias);
    end
    fprintf('  lag of the optical sensor: %+d s (correlation %.2f)\n', lag, xcMax);

    if f == numel(files)                                % figure of the last run
        fig13 = figure('Name', 'Optical vs strap', 'Position', [100 100 1000 650]);
        subplot(2, 1, 1)
        plot(ts / 60, hs, 'LineWidth', 1.2); hold on
        plot(ts / 60, hw, 'LineWidth', 1.2);
        yl = ylim;
        area(ts / 60, isStr * yl(2), yl(1), 'FaceColor', [0.85 0.85 0.85], ...
            'EdgeColor', 'none', 'FaceAlpha', 0.5);
        ylim(yl);  uistack(findobj(gca, 'Type', 'area'), 'bottom');
        ylabel('HR [bpm]');  grid on
        legend({'strides', 'strap (HRM 600)', 'watch (optical)'}, 'Location', 'southeast');
        title(sprintf('Validation run %s', datestr(g(1), 'dd mmm yyyy')));
        subplot(2, 1, 2)
        mm = (hw + hs) / 2;  ee = hw - hs;  q = res(end - 1);   % steady
        plot(mm(ok & ~steady), ee(ok & ~steady), '.', 'Color', [0.75 0.75 0.75]); hold on
        plot(mm(ok & steady), ee(ok & steady), '.');
        yline(q.bias, '-');  yline([q.loaLow q.loaHigh], '--');
        xlabel('mean of the two [bpm]');  ylabel('watch - strap [bpm]');  grid on
        legend({'other samples', 'steady'}, 'Location', 'best');
        title(sprintf('Bland-Altman, steady: bias %+.1f bpm, LoA [%+.1f, %+.1f]', ...
            q.bias, q.loaLow, q.loaHigh));
        exportgraphics(fig13, fullfile(cfg.paths.results, 'fig13_validation.png'), 'Resolution', 200);
    end
end

T = struct2table(res);
writetable(T, fullfile(cfg.paths.results, 'validation_runs.csv'));
fprintf('\nAcceptance (all runs pooled, decided on 10-11 Dec): |EF bias| <= %.0f %%, steady LoA within +-%d bpm\n', ...
    100 * V.accEF, V.accLoA);
fprintf('Saved: results/validation_runs.csv, results/fig13_validation.png\n');
