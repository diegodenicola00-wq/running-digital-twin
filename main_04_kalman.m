%% MAIN_04_KALMAN  Step 4: state estimation with a Kalman filter
%
% Needs the outputs of main_01_pipeline and main_03_identification.
%
%  1. Measurements: dynamic EF (Step 3), one value per day (mean if two runs).
%  2. Model: Banister states with literature time constants (Step 3 decision)
%     plus an aerobic baseline b (random walk); EF = b + c2*x2 + noise.
%     Measurement noise sigma from pairs of close runs (Step 3), independent.
%  3. Tuning: c2, qb, rho by maximum likelihood of the innovations,
%     on the training window only (idStart .. valStart-1).
%  4. Validation: one-step-ahead prediction of the EF from valStart on,
%     compared with simple predictors; consistency checks of the innovations.
%  5. Observability of the model, state of today.
%
% Outputs:
%   data/processed/kalman.mat
%   results/fig06_kalman.png, fig07_innovations.png  (+ PDFs in report/figures)

clear; clc;
startup_project;
cfg = config();

S = load(fullfile(cfg.paths.processed, 'daily_load.mat'), 'D');   D = S.D;
S = load(fullfile(cfg.paths.processed, 'identification.mat'), 'Td', 'sigmaDyn');
Td = S.Td;  sigma = S.sigmaDyn;

w = D.w;  N = numel(w);
dayIx = @(d) days(d - D.day(1)) + 1;

%% 1. Measurements: one value per day
[g, mDay] = findgroups(Td.day);
yd = splitapply(@mean, Td.ef_dyn, g);
nd = splitapply(@numel, Td.ef_dyn, g);
km = dayIx(mDay);
ok = km >= 1 & km <= N;
mDay = mDay(ok);  yd = yd(ok);  nd = nd(ok);  km = km(ok);
fprintf('Measurements: %d days (%d runs), sigma = %.3f m/beat per run\n', ...
    numel(yd), sum(nd), sigma);

%% 2. Base parameters
p = cfg.kf;
par = struct('tau1', p.tau1, 'tau2', p.tau2, 'c1', p.c1, 'c2', 0, 'qb', 0, ...
    'rho', 0, 'sigma', sigma, 'b0', mean(yd(1:p.nInit)), 'Pb0', p.Pb0, ...
    'Px0', p.Px0, 'llStart', dayIx(cfg.dates.idStart), ...
    'llEnd', dayIx(cfg.id.valStart) - 1);

%% 3. Maximum likelihood on the training window
nc = numel(p.c2Grid);  nq = numel(p.qbGrid);  nr = numel(p.rhoGrid);
LL = nan(nc, nq, nr);
for i = 1:nc
    for j = 1:nq
        for r = 1:nr
            pr = par;  pr.c2 = p.c2Grid(i);  pr.qb = p.qbGrid(j);  pr.rho = p.rhoGrid(r);
            F = kf_banister(w, km, yd, nd, pr);
            LL(i, j, r) = F.ll;
        end
    end
end
[llBest, iBest] = max(LL(:));
[i, j, r] = ind2sub(size(LL), iBest);
best = par;  best.c2 = p.c2Grid(i);  best.qb = p.qbGrid(j);  best.rho = p.rhoGrid(r);
fprintf('\nMaximum likelihood (training %s .. %s):\n', ...
    datestr(cfg.dates.idStart, 'dd-mmm'), datestr(cfg.id.valStart - 1, 'dd-mmm'));
fprintf('  c2 = %.1e m/beat per TRIMP, qb = %.0e (m/beat)^2/day, rho = %.1f, log-lik = %.1f\n', ...
    best.c2, best.qb, best.rho, llBest);

% profile of the likelihood over c2 (best qb, rho for each c2)
llProf = max(reshape(LL, nc, []), [], 2);
fprintf('  log-lik without fatigue term (c2 = 0): %.1f  (difference %.1f)\n', ...
    llProf(1), llBest - llProf(1));

% same filter without the fatigue term, for comparison
[~, i0] = max(reshape(LL(1, :, :), 1, []));
[j0, r0] = ind2sub([nq, nr], i0);
noFat = par;  noFat.c2 = 0;  noFat.qb = p.qbGrid(j0);  noFat.rho = p.rhoGrid(r0);

%% 4. Validation: one-step-ahead prediction from valStart
Fb = kf_banister(w, km, yd, nd, best);
F0 = kf_banister(w, km, yd, nd, noFat);
te = mDay >= cfg.id.valStart;
tr = mDay >= cfg.dates.idStart & mDay < cfg.id.valStart;
it = find(te);

predMean = mean(yd(tr)) * ones(numel(it), 1);
predLast = yd(it - 1);
predTrail = arrayfun(@(q) mean(yd(max(1, q-7):q-1)), it);
predKF   = Fb.yhat(km(te));
predKF0  = F0.yhat(km(te));

rmse = @(pr) sqrt(mean((yd(te) - pr).^2));
names = ["Kalman (with fatigue)"; "Kalman (no fatigue term)"; ...
         "mean of training"; "last value"; "mean of last 7"];
V = table(names, [rmse(predKF); rmse(predKF0); rmse(predMean); rmse(predLast); rmse(predTrail)], ...
    'VariableNames', {'predictor', 'rmse'});
fprintf('\nValidation: one-step-ahead prediction of the dynamic EF, %d days from %s\n', ...
    numel(it), datestr(cfg.id.valStart, 'dd-mmm'));
disp(V);

% consistency of the filter: normalized innovations should be ~N(0,1) and white
mm  = km >= dayIx(cfg.dates.idStart);
nu  = Fb.e(km(mm)) ./ sqrt(Fb.S(km(mm)));
cc  = corrcoef(nu(1:end-1), nu(2:end));
nis = mean(Fb.e(km(te)).^2 ./ Fb.S(km(te)));
fprintf('Normalized innovations (from %s, n = %d): std = %.2f (ideal 1), lag-1 autocorr = %+.2f (|.| < %.2f ok)\n', ...
    datestr(cfg.dates.idStart, 'dd-mmm'), numel(nu), std(nu), cc(1, 2), 2/sqrt(numel(nu)));
fprintf('Mean NIS on the validation days: %.2f (ideal 1)\n', nis);
nuV = Fb.e(km(te)) ./ sqrt(Fb.S(km(te)));
fprintf('Validation innovations: mean %+.2f (std error %.2f), %d of %d positive\n', ...
    mean(nuV), 1/sqrt(numel(nuV)), nnz(nuV > 0), numel(nuV));

%% 5. Observability and state of today
Am = diag([exp(-1/best.tau1), exp(-1/best.tau2), 1]);
Cm = [best.c1, best.c2, 1];
Ob = [Cm; Cm*Am; Cm*Am^2];
fprintf('\nObservability matrix: rank %d of 3, singular values %s\n', rank(Ob), mat2str(svd(Ob)', 3));
if rank(Ob) < 3
    fprintf('  -> fitness x1 is NOT observable from the EF: it is propagated open loop from the load.\n');
end

zT = Fb.z(N, :);  sT = sqrt(Fb.Pdiag(N, :));
fprintf('\nState on %s:\n', datestr(D.day(N), 'dd-mmm-yyyy'));
fprintf('  fitness  x1 = %6.0f +- %.0f TRIMP\n', zT(1), sT(1));
fprintf('  fatigue  x2 = %6.0f +- %.0f TRIMP   (effect on EF: %+.3f m/beat)\n', zT(2), sT(2), best.c2*zT(2));
fprintf('  baseline b  = %6.3f +- %.3f m/beat (from %.3f on %s)\n', zT(3), sT(3), ...
    Fb.z(dayIx(cfg.id.valStart), 3), datestr(cfg.id.valStart, 'dd-mmm'));

save(fullfile(cfg.paths.processed, 'kalman.mat'), 'Fb', 'best', 'LL', 'llProf', 'V', ...
    'mDay', 'yd', 'nd', 'km');

%% 6. Figures
dd   = D.day;
bS   = sqrt(Fb.Pdiag(:, 3));
yCor = yd - best.c2 * Fb.z(km, 2);                % EF with the fatigue effect removed

fig6 = figure('Name', 'Kalman filter', 'Position', [100 100 1000 650]);
tiledlayout(fig6, 2, 1, 'TileSpacing', 'compact');
nexttile; hold on
plot(mDay, yd, 'o', 'Color', [0.65 0.65 0.65], 'DisplayName', 'dynamic EF (measured)');
plot(mDay, yCor, '.', 'Color', [0.1 0.1 0.1], 'MarkerSize', 12, 'DisplayName', 'EF minus fatigue effect');
plot(dd, Fb.z(:, 3), '-', 'LineWidth', 2, 'Color', [0 0.45 0.74], 'DisplayName', 'baseline b (filtered)');
plot(dd, Fb.z(:, 3) + 2*bS, '--', 'Color', [0 0.45 0.74], 'DisplayName', '\pm 2\sigma');
plot(dd, Fb.z(:, 3) - 2*bS, '--', 'Color', [0 0.45 0.74], 'HandleVisibility', 'off');
xline(cfg.id.valStart, ':', 'validation start', 'HandleVisibility', 'off');
xline(cfg.dates.race10k, ':', '10 km race', 'HandleVisibility', 'off');
ylabel('EF [m per net beat]'); grid on; legend('Location', 'northwest');
title('Aerobic baseline estimated by the Kalman filter');
nexttile; hold on
plot(dd, Fb.z(:, 1), '-', 'LineWidth', 2, 'DisplayName', sprintf('fitness x_1 (\\tau = %d d)', best.tau1));
plot(dd, Fb.z(:, 2), '-', 'LineWidth', 1.5, 'DisplayName', sprintf('fatigue x_2 (\\tau = %d d)', best.tau2));
xline(cfg.id.valStart, ':', 'HandleVisibility', 'off');
xline(cfg.dates.race10k, ':', 'HandleVisibility', 'off');
ylabel('state [TRIMP]'); grid on; legend('Location', 'northwest');
title('Banister states (x_1 not observable: open loop)');
exportgraphics(fig6, fullfile(cfg.paths.results, 'fig06_kalman.png'), 'Resolution', 200);
export_report_figure(fig6, 'fig06_kalman', cfg);

fig7 = figure('Name', 'Innovations', 'Position', [100 100 1000 400]);
tiledlayout(fig7, 1, 2, 'TileSpacing', 'compact');
nexttile; hold on
nuAll = Fb.e(km) ./ sqrt(Fb.S(km));
plot(mDay(~te), nuAll(~te), 'o', 'Color', [0.5 0.5 0.5], 'DisplayName', 'training');
plot(mDay(te), nuAll(te), 'o', 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'none', ...
    'DisplayName', 'validation');
yline([-2 2], '--', 'HandleVisibility', 'off');  yline(0, '-', 'HandleVisibility', 'off');
xline(cfg.dates.idStart, ':', 'HandleVisibility', 'off');
ylabel('normalized innovation [-]'); grid on; legend('Location', 'southwest');
title('Innovations e / \surd S');
nexttile
plot(p.c2Grid * 1e4, llProf - llBest, '-o', 'LineWidth', 1.5); hold on
yline(-1.92, '--', '95% (likelihood ratio)', 'LabelHorizontalAlignment', 'left', ...
    'LabelVerticalAlignment', 'bottom');
xlabel('c_2 [10^{-4} m/beat per TRIMP]'); ylabel('log-likelihood - max'); grid on
title('Profile likelihood of the fatigue effect');
exportgraphics(fig7, fullfile(cfg.paths.results, 'fig07_innovations.png'), 'Resolution', 200);
export_report_figure(fig7, 'fig07_innovations', cfg);

fprintf('\nSaved: data/processed/kalman.mat, results/fig06_kalman.png, results/fig07_innovations.png\n');
