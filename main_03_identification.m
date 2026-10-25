%% MAIN_03_IDENTIFICATION  Step 3: identification of the Banister model
%
% Needs the outputs of main_01_pipeline and main_02_performance.
%
%  1. Banister model fitted by variable projection on the steady-run EF
%     (Step 2), identification window from cfg.dates.idStart.
%  2. Dynamic EF on ALL runs (pooled first-order HR model, dynamic_ef.m).
%  3. Banister model fitted on the dynamic EF.
%  4. Literature time constants fixed: significance and SIGN of the two states.
%  5. Validation: fit until cfg.id.valStart, predict the rest.
%
% Result (25 Oct 2026, see notes/results_log.md): the model is NOT identifiable
% from HR-based performance measures; with fixed time constants the fatigue
% state RAISES the dynamic EF (HR at a given speed is lower after heavy training).
%
% Outputs:
%   data/processed/identification.mat
%   results/fig04_cost_map.png, fig05_dynamic_ef.png  (+ PDFs in report/figures)

clear; clc;
startup_project;
cfg = config();

S = load(fullfile(cfg.paths.processed, 'activities.mat'), 'A');   A = S.A;
S = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');   D = S.D;
S = load(fullfile(cfg.paths.processed, 'performance.mat'), 'P');  P = S.P;

w     = D.w;
dayIx = @(d) days(d - D.day(1)) + 1;      % calendar day -> index in w
t1g   = cfg.id.tau1Grid;
t2g   = cfg.id.tau2Grid;

%% 1. Banister on the steady-run EF
m1 = P.day >= cfg.dates.idStart;
R1 = varpro_banister(w, dayIx(P.day(m1)), P.ef(m1), t1g, t2g);
print_fit('Steady-run EF (Step 2)', R1);

%% 2. Dynamic EF on all runs
fprintf('\nDynamic EF: fitting the pooled HR model on all runs...\n');
[Td, M] = dynamic_ef(A, cfg);
fprintf('Pooled HR model on %d runs: T = %d s, G = %.1f bpm per m/s, drift = %.1f bpm/h, RMSE = %.2f bpm\n', ...
    M.nRuns, M.T_hr, M.G, M.drift, M.rmse);

% one value per day (mean if two runs on the same day)
[g, dDay] = findgroups(Td.day);
Pd = table(dDay, splitapply(@mean, Td.ef_dyn, g), 'VariableNames', {'day', 'ef_dyn'});

% noise from pairs of runs <= 3 days apart
dd = days(diff(Td.day));  dE = diff(Td.ef_dyn);  near = dd <= 3;
sigmaDyn = std(dE(near)) / sqrt(2);
fprintf('Dynamic EF: %d runs, noise sigma = %.3f m/beat (%.1f%%) from %d pairs, total std = %.3f\n', ...
    height(Td), sigmaDyn, 100*sigmaDyn/mean(Td.ef_dyn), nnz(near), std(Td.ef_dyn));

%% 3. Banister on the dynamic EF
m2 = Pd.day >= cfg.dates.idStart;
R2 = varpro_banister(w, dayIx(Pd.day(m2)), Pd.ef_dyn(m2), t1g, t2g);
print_fit('Dynamic EF', R2);

%% 4. Literature time constants: significance and sign of the states
fprintf('\nFixed time constants: t-statistics (fatigue: + means it RAISES the index)\n');
fprintf('  %-12s %-8s %-6s %10s %10s\n', 'series', 'tau', 'window', 't(fitness)', 't(fatigue)');
series = {'steady EF', P.day, P.ef; 'dynamic EF', Pd.day, Pd.ef_dyn};
tauSets = [42 7; 42 3; 60 10];
Tstat = table();
for s = 1:size(series, 1)
    for q = 1:size(tauSets, 1)
        for win = ["all", "Mar+"]
            dy = series{s, 2};  y = series{s, 3};
            m = true(size(dy));
            if win == "Mar+", m = dy >= cfg.dates.idStart; end
            x1 = banister_states(w, tauSets(q, 1));  x2 = banister_states(w, tauSets(q, 2));
            k  = dayIx(dy(m));
            X  = [ones(nnz(m), 1), x1(k), x2(k)];
            b  = X \ y(m);
            r  = y(m) - X*b;
            se = sqrt(diag(sum(r.^2) / (nnz(m) - 3) * inv(X' * X)));   %#ok<MINV>
            t  = b ./ se;
            fprintf('  %-12s %2d/%-5d %-6s %+10.1f %+10.1f\n', series{s, 1}, ...
                tauSets(q, 1), tauSets(q, 2), win, t(2), t(3));
            Tstat = [Tstat; table(string(series{s, 1}), tauSets(q, 1), tauSets(q, 2), win, t(2), t(3), ...
                'VariableNames', {'series', 'tau1', 'tau2', 'window', 't_fitness', 't_fatigue'})]; %#ok<AGROW>
        end
    end
end

%% 5. Validation: fit until valStart, predict afterwards
fprintf('\nValidation (fit %s .. %s, predict from %s):\n', ...
    datestr(cfg.dates.idStart, 'dd-mmm'), datestr(cfg.id.valStart - 1, 'dd-mmm'), ...
    datestr(cfg.id.valStart, 'dd-mmm'));
V = table();
for s = 1:size(series, 1)
    dy = series{s, 2};  y = series{s, 3};
    tr = dy >= cfg.dates.idStart & dy < cfg.id.valStart;
    te = dy >= cfg.id.valStart;
    Rt = varpro_banister(w, dayIx(dy(tr)), y(tr), t1g, t2g);
    x1 = banister_states(w, Rt.tau1);  x2 = banister_states(w, Rt.tau2);
    k  = dayIx(dy(te));
    yhat = Rt.theta(1) + Rt.theta(2)*x1(k) - Rt.theta(3)*x2(k);
    rmseModel = sqrt(mean((y(te) - yhat).^2));
    rmseMean  = sqrt(mean((y(te) - mean(y(tr))).^2));
    fprintf('  %-12s test n = %2d   RMSE model = %.4f   RMSE training mean = %.4f\n', ...
        series{s, 1}, nnz(te), rmseModel, rmseMean);
    V = [V; table(string(series{s, 1}), nnz(te), rmseModel, rmseMean, ...
        'VariableNames', {'series', 'nTest', 'rmseModel', 'rmseMean'})]; %#ok<AGROW>
end

save(fullfile(cfg.paths.processed, 'identification.mat'), 'R1', 'R2', 'M', 'Td', 'Pd', ...
    'sigmaDyn', 'Tstat', 'V');

%% 6. Figures
% cost map of the steady-run EF fit
fig4 = figure('Name', 'Cost map', 'Position', [100 100 800 550]);
L = 100 * (R1.J / R1.rss - 1);                  % RSS increase w.r.t. the best fit [%]
Lmax = max(L(:));
contourf(t2g, t1g, L, 0:0.25:ceil(Lmax), 'LineColor', 'none'); hold on
colormap(parula); clim([0 ceil(Lmax)]);
cb = colorbar; cb.Label.String = 'RSS increase w.r.t. the best fit [%]';
plot(R1.tau2, R1.tau1, 'kp', 'MarkerFaceColor', 'w', 'MarkerSize', 14);
plot(7, 42, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 9);
xlabel('\tau_2 fatigue [days]'); ylabel('\tau_1 fitness [days]');
title({'Banister fit on the steady-run EF: residual map', ...
       sprintf('the whole grid is within +%.1f%% of the best fit', Lmax)});
text(0.97, 0.20, '\tau_2 \geq \tau_1 (excluded)', 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'Color', [0.4 0.4 0.4]);
legend({'', 'best fit', 'literature (42, 7)'}, 'Location', 'southeast');
text(0.03, 0.04, sprintf('95%% confidence region: whole grid (\\tau_1 %g-%g d, \\tau_2 %g-%g d)', ...
    R1.tau1Range, R1.tau2Range), 'Units', 'normalized', 'BackgroundColor', 'w');
exportgraphics(fig4, fullfile(cfg.paths.results, 'fig04_cost_map.png'), 'Resolution', 200);
export_report_figure(fig4, 'fig04_cost_map', cfg);

% dynamic EF vs steady EF over time
fig5 = figure('Name', 'Dynamic EF', 'Position', [100 100 1000 450]); hold on
plot(Td.day, Td.ef_dyn, 'o', 'Color', [0.6 0.6 0.6], 'DisplayName', 'dynamic EF, all runs');
plot(P.day, P.ef, 'o', 'MarkerFaceColor', [0 0.45 0.74], 'MarkerEdgeColor', 'none', ...
    'DisplayName', 'steady-run EF (Step 2)');
plot(Td.day, movmedian(Td.ef_dyn, 7), '-', 'LineWidth', 2, 'Color', [0.85 0.33 0.10], ...
    'DisplayName', 'dynamic EF, 7-run median');
xline(cfg.dates.idStart, ':', 'identification start', 'HandleVisibility', 'off');
xline(cfg.id.valStart, ':', 'validation start', 'HandleVisibility', 'off');
ylabel('EF [m per net beat]'); grid on; legend('Location', 'northwest');
title(sprintf('Dynamic EF (pooled HR model: T = %d s, G = %.1f bpm per m/s)', M.T_hr, M.G));
exportgraphics(fig5, fullfile(cfg.paths.results, 'fig05_dynamic_ef.png'), 'Resolution', 200);
export_report_figure(fig5, 'fig05_dynamic_ef', cfg);

fprintf('\nSaved: data/processed/identification.mat, results/fig04_cost_map.png, results/fig05_dynamic_ef.png\n');

%% ------------------------------------------------------------------------
function print_fit(name, R)
    fprintf('\n%s: n = %d, best tau1 = %g d, tau2 = %g d\n', name, R.n, R.tau1, R.tau2);
    fprintf('  p0 = %.3f, k1 = %.2e, k2 = %.2e, R2 = %.3f\n', R.theta(1), R.theta(2), R.theta(3), R.R2);
    fprintf('  AIC Banister = %.1f, AIC constant = %.1f\n', R.AIC, R.AICconst);
    fprintf('  95%% region: tau1 %g-%g d, tau2 %g-%g d\n', R.tau1Range, R.tau2Range);
end
