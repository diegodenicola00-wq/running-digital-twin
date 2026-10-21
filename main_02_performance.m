%% MAIN_02_PERFORMANCE  Step 2: aerobic-efficiency index as the performance measure p[k]
%
% Needs the output of main_01_pipeline (data/processed/activities.mat, daily_load.mat).
%
% For every run: efficiency_index -> EF [m per net heartbeat] + quality metrics,
% place (Milano / L'Aquila / other), altitude and weather at the time of the run.
% Runs used as performance measurements: easy (HR reserve <= cfg.perf.maxHRR)
% and steady (low pace variability, mostly steady samples). Intervals and races
% are excluded: HR lags behind short efforts and inflates EF.
%
% Heat effect: EF residuals w.r.t. a local running median (slow fitness changes
% removed) are regressed on air temperature -> slope b [m/beat per degC];
% EF is then corrected to cfg.perf.refTemp.
%
% Outputs:
%   data/processed/performance.mat   E (all runs), P (selected runs), sigma, heat
%   results/fig02_efficiency.png      EF over time (raw and temperature-corrected)
%   results/fig03_heat_effect.png     EF residual vs temperature, by place

clear; clc;
startup_project;
cfg = config();

S1 = load(fullfile(cfg.paths.processed, 'activities.mat'), 'A');
S2 = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');
A = S1.A;  D = S2.D;
assert(ismember('lat', A.Properties.VariableNames), ...
    'activities.mat has no GPS columns: run main_01_pipeline again first.');

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

%% 2. Context: place, altitude, weather
E.site  = site_label(A.lat, A.lon, cfg);
E.alt_m = A.alt_m;
fprintf('Fetching weather (Open-Meteo, ERA5)...\n');
W = get_weather(A, cfg);
E.temp = W.temp;  E.rh = W.rh;  E.app_temp = W.app_temp;
fprintf('Runs per place:\n');  disp(countcats(E.site)');  disp(categories(E.site)');
fprintf('%d runs without weather data.\n', nnz(isnan(E.temp)));

%% 3. Selection: easy, steady runs
% Runs without GPS (treadmill) are excluded: their speed comes from the wrist
% accelerometer, not from GPS, and is not comparable.
hasGPS = E.site ~= "no GPS";
E.use = ~isnan(E.ef) & hasGPS & E.cv <= cfg.perf.maxCV ...
      & E.steadyFrac >= cfg.perf.minSteady & E.hrr <= cfg.perf.maxHRR;

fprintf('\n%d runs, %d with a valid window, %d selected as easy+steady.\n', ...
    n, nnz(~isnan(E.ef)), nnz(E.use));
fprintf('Excluded: %d without GPS (treadmill), then %d too short, %d unsteady (CV/steady share), %d too intense.\n', ...
    nnz(~hasGPS), ...
    nnz(hasGPS & isnan(E.ef)), ...
    nnz(hasGPS & ~isnan(E.ef) & (E.cv > cfg.perf.maxCV | E.steadyFrac < cfg.perf.minSteady)), ...
    nnz(hasGPS & ~isnan(E.ef) & E.cv <= cfg.perf.maxCV & E.steadyFrac >= cfg.perf.minSteady ...
        & E.hrr > cfg.perf.maxHRR));

% Sensitivity of the selection to the pace-variability threshold
% (hilly L'Aquila runs and urban stops raise the CV of easy runs).
fprintf('\nSensitivity to maxCV:   maxCV   selected   of which L''Aquila\n');
for cvMax = [0.08 0.10 0.12 0.15]
    u = ~isnan(E.ef) & hasGPS & E.cv <= cvMax ...
        & E.steadyFrac >= cfg.perf.minSteady & E.hrr <= cfg.perf.maxHRR;
    fprintf('                        %.2f    %3d        %3d\n', cvMax, nnz(u), nnz(u & E.site == "L'Aquila"));
end

% Sensitivity to the steady-share threshold (hills make GAP fluctuate) and noise
fprintf('\nSensitivity to minSteady:  minSteady  selected  L''Aquila  Jul-Sep  sigma (pairs <= 3 d)\n');
for stMin = [0.60 0.70 0.80]
    u = ~isnan(E.ef) & hasGPS & E.cv <= cfg.perf.maxCV ...
        & E.steadyFrac >= stMin & E.hrr <= cfg.perf.maxHRR;
    Pu = E(u, :);
    nearU = days(diff(Pu.day)) <= 3;
    dU = diff(Pu.ef);
    summer = Pu.day >= datetime(2026,7,1) & Pu.day < datetime(2026,10,1);
    fprintf('                           %.2f      %3d       %3d       %3d      %.3f (n = %d)\n', ...
        stMin, nnz(u), nnz(u & E.site == "L'Aquila"), nnz(summer), ...
        std(dU(nearU)) / sqrt(2), nnz(nearU));
end
% why are L'Aquila runs excluded?
aqx = hasGPS & ~isnan(E.ef) & E.site == "L'Aquila" & ~E.use;
fprintf('L''Aquila runs excluded: %d  (CV > max: %d, steady share < min: %d, too intense: %d)\n', ...
    nnz(aqx), nnz(aqx & E.cv > cfg.perf.maxCV), ...
    nnz(aqx & E.steadyFrac < cfg.perf.minSteady), nnz(aqx & E.hrr > cfg.perf.maxHRR));

%% 4. Heat effect (within-season comparison)
% Slow changes of fitness are removed with a running median over the selected
% runs; the residual day-to-day differences are regressed on temperature.
% Note: part of the seasonal heat effect is absorbed by the running median,
% so the slope is a conservative (biased towards zero) estimate.
S = E(E.use & ~isnan(E.temp), :);
trend = movmedian(S.ef, cfg.perf.trendRuns);
res   = S.ef - trend;
X     = [ones(height(S),1), S.temp - cfg.perf.refTemp];
b     = X \ res;
r     = res - X*b;
se    = sqrt(diag(sum(r.^2) / (height(S) - 2) * inv(X' * X)));   %#ok<MINV>
heat.slope = b(2);  heat.se = se(2);  heat.n = height(S);
fprintf('\nHeat effect: %+.4f m/beat per degC (SE %.4f, n = %d) = %+.2f%% of mean EF per degC\n', ...
    b(2), se(2), height(S), 100*b(2)/mean(S.ef));

% same with apparent temperature (heat + humidity + wind), for comparison
Xa = [ones(height(S),1), S.app_temp - cfg.perf.refTemp];
ba = Xa \ res;
fprintf('With apparent temperature: %+.4f m/beat per degC\n', ba(2));

% residual by place (after removing temperature): altitude / terrain effect?
fprintf('Mean residual by place (after the temperature term):\n');
cats = categories(S.site);
for k = 1:numel(cats)
    sel = S.site == cats{k};
    if nnz(sel) >= 3
        fprintf('  %-10s %+.3f m/beat (n = %d)\n', cats{k}, mean(r(sel)), nnz(sel));
    end
end

E.ef_tc = E.ef - heat.slope * (E.temp - cfg.perf.refTemp);   % temperature-corrected

%% 5. Measurement noise: raw vs temperature-corrected
% Pairs of selected runs <= 3 days apart: fitness can hardly change in 3 days,
% so their difference is mostly measurement noise. sigma = std(diff)/sqrt(2).
P = E(E.use, {'day','ef','ef_tc','temp','site','alt_m'});
dd   = days(diff(P.day));
near = dd <= 3;
dEF   = diff(P.ef);
dTc   = diff(P.ef_tc);
pairs = near & ~isnan(dEF) & ~isnan(dTc);        % SAME pairs for both estimates
sigma   = std(dEF(pairs)) / sqrt(2);
sigmaTc = std(dTc(pairs)) / sqrt(2);
fprintf('\nNoise (same %d pairs <= 3 days apart): raw sigma = %.3f, temperature-corrected sigma = %.3f m/beat (%.1f%% of mean EF)\n', ...
    nnz(pairs), sigma, sigmaTc, 100*sigma/mean(P.ef));

save(fullfile(cfg.paths.processed, 'performance.mat'), 'E', 'P', 'sigma', 'sigmaTc', 'heat');

%% 6. Figure: EF over time, raw and temperature-corrected
ewma = @(x, tau) filter(1 - exp(-1/tau), [1, -exp(-1/tau)], x);
ctl  = ewma(D.w, 42);
gapIdx = find(days(diff(A.day)) >= 7);              % rest periods >= 7 days

fig = figure('Name', 'Aerobic efficiency', 'Position', [100 100 1000 700]);
tiledlayout(2, 1, 'TileSpacing', 'compact');

ax1 = nexttile; hold on
for g = gapIdx'
    xline([A.day(g) A.day(g+1)], '-', 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
end
aq = P.site == "L'Aquila";
plot(P.day(~aq), P.ef(~aq), 'o', 'MarkerFaceColor', [0 0.45 0.74], ...
    'MarkerEdgeColor', 'none', 'DisplayName', 'EF raw, Milano/other');
plot(P.day(aq), P.ef(aq), 'o', 'MarkerFaceColor', [0.47 0.67 0.19], ...
    'MarkerEdgeColor', 'none', 'DisplayName', 'EF raw, L''Aquila');
plot(P.day, movmedian(P.ef, 5), '-', 'LineWidth', 1.5, 'Color', [0 0.45 0.74], ...
    'DisplayName', 'running median, raw');
plot(P.day, movmedian(P.ef_tc, 5, 'omitnan'), '-', 'LineWidth', 2.5, ...
    'Color', [0.85 0.33 0.10], ...
    'DisplayName', sprintf('running median, corrected to %d °C', cfg.perf.refTemp));
xline(cfg.dates.planStart, ':', 'plan start', 'HandleVisibility', 'off');
xline(cfg.dates.race10k,   ':', '10 km race', 'HandleVisibility', 'off');
ylabel('EF [m per net beat]'); grid on
legend('Location', 'northwest');
title('Aerobic efficiency of easy steady runs (grey lines: rest periods >= 7 days)');

ax2 = nexttile;
plot(D.day, ctl, 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]);
ylabel('fitness proxy (\tau = 42 d)'); grid on
title('Training load, EWMA (literature time constant, not identified)');

linkaxes([ax1 ax2], 'x');
xlim([cfg.dates.dataStart, max(D.day)]);
exportgraphics(fig, fullfile(cfg.paths.results, 'fig02_efficiency.png'), 'Resolution', 200);
export_report_figure(fig, 'fig02_efficiency', cfg);

%% 7. Figure: heat effect
fig3 = figure('Name', 'Heat effect', 'Position', [150 150 700 500]); hold on
for k = 1:numel(cats)
    sel = S.site == cats{k};
    if any(sel)
        scatter(S.temp(sel), res(sel), 40, 'filled', 'DisplayName', cats{k});
    end
end
tt = linspace(min(S.temp), max(S.temp), 50)';
plot(tt, b(1) + b(2)*(tt - cfg.perf.refTemp), 'k-', 'LineWidth', 2, ...
    'DisplayName', sprintf('fit: %+.4f m/beat per °C', b(2)));
yline(0, ':', 'HandleVisibility', 'off');
xlabel('air temperature during the run [°C]');
ylabel('EF residual vs running median [m/beat]');
title('Heat effect on aerobic efficiency (easy steady runs)');
legend('Location', 'best'); grid on
exportgraphics(fig3, fullfile(cfg.paths.results, 'fig03_heat_effect.png'), 'Resolution', 200);
export_report_figure(fig3, 'fig03_heat_effect', cfg);

fprintf('Saved: data/processed/performance.mat, results/fig02_efficiency.png, results/fig03_heat_effect.png\n');
