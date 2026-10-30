%% MAIN_05_TAPER  Step 5: optimal taper planning (MPC on the literature model)
%
% Needs the outputs of main_01_pipeline (daily load up to the last run).
% Run it again every week with the new runs: it re-plans from the current state
% (receding horizon). Every run saves the plan in results/taper_plan_<date>.csv.
%
%  1. History of the load and plan start.
%  2. Limits from the athlete's recent training (taper_limits.m).
%  3. Nominal plan (literature parameters) and ROBUST plan (worst case over
%     uncertain fatigue parameters), linear programs (taper_lp.m).
%  4. Sensitivity: optimal taper length for every scenario.
%  5. Closed loop: open-loop plan vs weekly re-planning (MPC) with execution
%     errors and skipped sessions (Monte Carlo).
%
% Outputs:
%   data/processed/mpc.mat, results/taper_plan_<yyyymmdd>.csv
%   results/fig08_taper.png, fig09_robust.png  (+ PDFs in report/figures)

clear; clc;
startup_project;
cfg = config();
P = cfg.mpc;
raceDay = cfg.dates.raceHalf;
dayName = {'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'};   % weekday() order, locale-free

S = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');   D = S.D;

%% 1. History and plan start
lastRun = D.day(find(D.w > 0, 1, 'last'));
today   = dateshift(datetime('today'), 'start', 'day');
if isempty(P.planStart)
    start = max(today, lastRun + caldays(1));
else
    start = P.planStart;
end
if days(start - lastRun) > P.maxDataAge + 1
    warning(['Last run in the data: %s. If you ran after that, add the new FIT files ', ...
             'and run main_01_pipeline first: the plan starts from the wrong state.'], ...
             datestr(lastRun, 'dd-mmm-yyyy'));
end
dHist = (D.day(1) : caldays(1) : start - caldays(1))';
wHist = zeros(size(dHist));  kmHist = wHist;
[tf, loc] = ismember(D.day, dHist);
wHist(loc(tf)) = D.w(tf);  kmHist(loc(tf)) = D.km(tf);
fprintf('Last run: %s.  Plan from %s to %s (%d days).\n', datestr(lastRun, 'ddd dd-mmm'), ...
    datestr(start, 'ddd dd-mmm'), datestr(raceDay - 1, 'ddd dd-mmm'), days(raceDay - start));

%% 2. Limits from recent training
lim = taper_limits(dHist, wHist, kmHist, P);
fprintf('\nLimits from the last %d weeks:\n', P.capWeeks);
for j = 1:numel(P.runDays)
    fprintf('  %-8s (%s): usual %3.0f, max %3.0f TRIMP, min in the plan %3.0f; %.1f TRIMP/km (%d sessions)\n', ...
        P.sessionName(j), dayName{P.runDays(j)}, lim.ref(j), lim.cap(j), P.minFrac*lim.ref(j), ...
        lim.rate(j), lim.n(j));
end
fprintf('  weekly load (Mon-Sun) <= %.0f TRIMP (max of the last %d weeks)\n', lim.weekCap, P.weekCapWeeks);

%% 3. Nominal and robust plans
[wNom, infoN] = taper_lp(dHist, wHist, raceDay, lim, P, 'nominal');
for q = find(infoN.fixed)'
    fprintf('Fixed by you: %s %s, %.0f TRIMP (%.0f km)\n', datestr(infoN.days(q), 'ddd dd-mmm'), ...
        P.sessionName(infoN.type(q)), infoN.lb(q), infoN.lb(q) / lim.rate(infoN.type(q)));
end
[wRob, infoR] = taper_lp(dHist, wHist, raceDay, lim, P, 'robust');
H = infoR.days;  type = infoR.type;  F = infoR.F;  c = infoR.c;  pStar = infoR.pStar;
wHab = zeros(size(H));  wHab(type > 0) = lim.ref(type(type > 0));      % usual training, no taper
rel = @(w) (c + F*w) ./ pStar;

on = type > 0;
names = strings(size(H));  names(on) = P.sessionName(type(on));
km = zeros(size(H));  km(on) = wRob(on) ./ lim.rate(type(on))';
Plan = table(H(on), string(dayName(weekday(H(on))))', names(on), round(wNom(on)), ...
    round(wRob(on)), round(km(on), 1), 'VariableNames', ...
    {'date', 'day', 'session', 'trimp_nominal', 'trimp_robust', 'km_robust'});
fprintf('\nPlan (robust = the one to follow; km at your usual intensity for that session):\n');
disp(Plan);

wk = floor(days(H - datetime(2000, 1, 3)) / 7);
[gw, ~] = findgroups(wk);
Wk = table(splitapply(@(d) d(1), H, gw), splitapply(@sum, wNom, gw), splitapply(@sum, wRob, gw), ...
    splitapply(@sum, wHab, gw), 'VariableNames', {'from', 'nominal', 'robust', 'usual'});
fprintf('Planned load per week (days from the plan start only):\n');
disp(Wk);

%% 4. Scenarios: performance of each plan and optimal taper length
sc = infoR.scen;  nS = size(sc, 1);
taperDays = nan(nS, 1);
for s = 1:nS
    Ps = P;  Ps.k2 = sc(s, 1);  Ps.tau2 = sc(s, 2);
    ws = taper_lp(dHist, wHist, raceDay, lim, Ps, 'nominal');
    iFull = find(on & ~infoR.fixed & ws >= 0.9 * infoR.ub, 1, 'last');
    if isempty(iFull), taperDays(s) = days(raceDay - start);
    else, taperDays(s) = days(raceDay - H(iFull)) - 1; end
end
Rs = table(sc(:, 1), sc(:, 2), taperDays, 100*rel(wNom), 100*rel(wRob), 100*rel(wHab), ...
    'VariableNames', {'k2', 'tau2', 'optimal_taper_days', 'nominal_pct', 'robust_pct', 'usual_pct'});
fprintf(['Scenarios: race-day performance of each plan, %% of the best achievable in that scenario (with the fixed sessions)\n', ...
         '(optimal_taper_days: days between the last full session and the race, if that scenario were true)\n']);
disp(Rs);
fprintf('Worst case: nominal plan %.1f%%, robust plan %.1f%%, usual training %.1f%%\n', ...
    100*min(rel(wNom)), 100*min(rel(wRob)), 100*min(rel(wHab)));

%% 5. Closed loop: open-loop plan vs weekly re-planning (MPC)
rng(P.seed);
n = numel(H);
MC = zeros(P.nMC, 6);
fprintf('\nClosed-loop simulation (%d runs, execution error %.0f%%, %.0f%% skipped sessions)...\n', ...
    P.nMC, 100*P.loadStd, 100*P.pMiss);
for r = 1:P.nMC
    e = max(0, 1 + P.loadStd*randn(n, 1));
    skip = rand(n, 1) < P.pMiss;
    % open loop: the first plan is followed as it is
    wOL = wRob .* e;  wOL(skip) = 0;
    % MPC: re-plan every P.replanDays days from what was actually done
    dC = dHist;  wC = wHist;  i = 1;
    while i <= n
        wp = taper_lp(dC, wC, raceDay, lim, P, 'robust');
        seg = 1:min(P.replanDays, n - i + 1);
        act = wp(seg) .* e(i - 1 + seg);  act(skip(i - 1 + seg)) = 0;
        dC = [dC; H(i - 1 + seg)];  wC = [wC; act];            %#ok<AGROW>
        i = i + numel(seg);
    end
    wMPC = wC(end - n + 1:end);
    rOL = rel(wOL);  rM = rel(wMPC);
    MC(r, :) = [min(rOL), rOL(infoR.iNom), weeks_over(dHist, wHist, H, wOL, lim.weekCap), ...
                min(rM),  rM(infoR.iNom),  weeks_over(dHist, wHist, H, wMPC, lim.weekCap)];
end
fprintf('  open loop : worst case %.1f +- %.1f %%, nominal %.1f %%, weeks over the cap %.2f\n', ...
    100*mean(MC(:, 1)), 100*std(MC(:, 1)), 100*mean(MC(:, 2)), mean(MC(:, 3)));
fprintf('  MPC       : worst case %.1f +- %.1f %%, nominal %.1f %%, weeks over the cap %.2f\n', ...
    100*mean(MC(:, 4)), 100*std(MC(:, 4)), 100*mean(MC(:, 5)), mean(MC(:, 6)));
fprintf('  MPC better than open loop (worst case) in %.0f%% of the runs\n', 100*mean(MC(:, 4) > MC(:, 1)));

%% Save
stamp = datestr(start, 'yyyymmdd');
writetable(Plan, fullfile(cfg.paths.results, ['taper_plan_' stamp '.csv']));
save(fullfile(cfg.paths.processed, 'mpc.mat'), 'Plan', 'Wk', 'Rs', 'MC', 'lim', 'wNom', 'wRob', ...
    'wHab', 'infoR', 'start', 'raceDay');

%% 6. Figures
dPast = dHist(dHist >= start - caldays(42));
wPast = wHist(dHist >= start - caldays(42));
fig8 = figure('Name', 'Taper plan', 'Position', [100 100 1000 650]);
tiledlayout(fig8, 2, 1, 'TileSpacing', 'compact');
nexttile; hold on
bar(dPast, wPast, 0.8, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none', 'DisplayName', 'done');
bar(H, wRob, 0.8, 'FaceColor', [0 0.45 0.74], 'EdgeColor', 'none', 'DisplayName', 'robust plan');
plot(H(on), wNom(on), 'o', 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5, 'DisplayName', 'nominal plan');
xline(start - hours(12), ':', 'today', 'HandleVisibility', 'off');
xline(raceDay, '-', 'half marathon', 'HandleVisibility', 'off');
ylabel('daily TRIMP'); grid on; legend('Location', 'northwest');
title('Training load: last 6 weeks and plan to the race');
nexttile; hold on
dAll = [dHist; H; raceDay];
cols = {[0 0.45 0.74], [0.85 0.33 0.10], [0.5 0.5 0.5]};
lab  = {'robust plan', 'nominal plan', 'usual training (no taper)'};
plans = {wRob, wNom, wHab};
for q = 1:3
    pp = perf_path([wHist; plans{q}], P.tau1, P.tau2, P.k1, P.k2);
    keep = dAll >= start - caldays(42);
    plot(dAll(keep), 100*pp(keep)/pStar(infoR.iNom), '-', 'LineWidth', 2, 'Color', cols{q}, ...
        'DisplayName', lab{q});
end
xline(start - hours(12), ':', 'HandleVisibility', 'off');
xline(raceDay, '-', 'HandleVisibility', 'off');
ylabel('p = k_1x_1 - k_2x_2  [% of best on race day]'); grid on; legend('Location', 'southwest');
title(sprintf('Predicted performance (nominal model: k_2/k_1 = %g, \\tau_2 = %g d)', P.k2, P.tau2));
exportgraphics(fig8, fullfile(cfg.paths.results, 'fig08_taper.png'), 'Resolution', 200);
export_report_figure(fig8, 'fig08_taper', cfg);

fig9 = figure('Name', 'Robustness', 'Position', [100 100 1000 420]);
labs = arrayfun(@(s) sprintf('%g / %g d', sc(s, 1), sc(s, 2)), 1:nS, 'UniformOutput', false);
bh = bar(categorical(labs, labs), [Rs.usual_pct, Rs.nominal_pct, Rs.robust_pct], 0.85);
bh(1).FaceColor = [0.6 0.6 0.6];  bh(2).FaceColor = [0.85 0.33 0.10];  bh(3).FaceColor = [0 0.45 0.74];
ylim([min([Rs.usual_pct; Rs.nominal_pct]) - 3, 101]);
xlabel('scenario  k_2/k_1 / \tau_2'); ylabel('% of best achievable'); grid on
legend({'usual training', 'nominal plan', 'robust plan'}, 'Location', 'southwest');
title(sprintf('Race-day performance in every scenario (worst case: nominal %.1f%%, robust %.1f%%)', ...
    100*min(rel(wNom)), 100*min(rel(wRob))));
exportgraphics(fig9, fullfile(cfg.paths.results, 'fig09_robust.png'), 'Resolution', 200);
export_report_figure(fig9, 'fig09_robust', cfg);

fprintf('\nSaved: data/processed/mpc.mat, results/taper_plan_%s.csv, results/fig08_taper.png, results/fig09_robust.png\n', stamp);

%% ------------------------------------------------------------------------
function p = perf_path(w, tau1, tau2, k1, k2)
% Performance on every day from the first day of w to the day after its last
% day (state of a day = load of the days before it).
    x1 = filter(1, [1, -exp(-1/tau1)], w);
    x2 = filter(1, [1, -exp(-1/tau2)], w);
    p = [0; k1*x1 - k2*x2];
end

function nOver = weeks_over(dHist, wHist, H, wEx, cap)
% Number of Mon-Sun weeks of the plan whose total load exceeds the cap by > 1%.
    d = [dHist; H];  w = [wHist; wEx];
    wk = floor(days(d - datetime(2000, 1, 3)) / 7);
    ids = unique(floor(days(H - datetime(2000, 1, 3)) / 7));
    nOver = sum(arrayfun(@(i) sum(w(wk == i)) > 1.01*cap, ids));
end
