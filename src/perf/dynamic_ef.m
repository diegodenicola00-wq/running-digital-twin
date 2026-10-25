function [T, M] = dynamic_ef(A, cfg)
%DYNAMIC_EF Aerobic efficiency of EVERY run from a pooled first-order HR model.
%
%   [T, M] = dynamic_ef(A, cfg)
%
% Heart rate is modelled as the delayed response to grade-adjusted speed:
%
%   HR(t) = c_run + G * z(t) + d * t,    z = v_GAP filtered by 1/(T_hr s + 1)
%
% The physiology (gain G, time constant T_hr, drift d) is SHARED by all runs and
% estimated once (within-run least squares on a grid of T_hr); every run only
% has its own offset c_run. From it, the HR predicted at a reference speed and
% time gives a "dynamic EF" that can be computed also on hilly runs and intervals.
%
%   HR_ref = c_run + G * v_ref + d * t_ref
%   EF_dyn = v_ref[m/min] / (HR_ref - HRrest)
%
% Excluded: runs without GPS (treadmill) and near-maximal runs (races), where
% the HR-speed relation is no longer linear.
%
% Outputs
%   T  table, one row per run used: day, ef_dyn, hr_ref, rmse [bpm], hr_mean
%   M  struct with the shared model: G [bpm per m/s], T_hr [s], drift [bpm/h], rmse

    p = cfg.dyn;
    n = height(A);
    runs = cell(n, 1);
    keep = false(n, 1);
    for i = 1:n
        r = A.rec{i};
        if isnan(A.lat(i)), continue; end                 % treadmill: no GPS
        [h, vg, tt] = prepare_run(r);
        if isempty(h), continue; end
        use = tt >= p.skipSec & h >= cfg.clean.hrMin & ~isnan(h) & ~isnan(vg);
        if nnz(use) < p.minSamples, continue; end
        if mean(h(use)) >= p.maxMeanHR, continue; end     % races / maximal efforts
        runs{i} = struct('h', h, 'vg', vg, 't', tt, 'use', use);
        keep(i) = true;
    end
    idx = find(keep);

    % --- shared model: grid on T_hr, within-run least squares for G and drift
    best = struct('rss', inf);
    for Thr = p.Tgrid
        Y = [];  Z = [];  Tt = [];
        for i = idx'
            s = runs{i};
            z = lag1(s.vg, Thr);
            y = s.h(s.use);  zz = z(s.use);  th = s.t(s.use) / 3600;
            Y = [Y; y - mean(y)];  Z = [Z; zz - mean(zz)];  Tt = [Tt; th - mean(th)]; %#ok<AGROW>
        end
        X = [Z, Tt];
        b = X \ Y;
        rss = sum((Y - X*b).^2);
        if rss < best.rss
            best = struct('rss', rss, 'T_hr', Thr, 'G', b(1), 'drift', b(2), 'N', numel(Y));
        end
    end
    M = struct('G', best.G, 'T_hr', best.T_hr, 'drift', best.drift, ...
               'rmse', sqrt(best.rss / best.N), 'nRuns', numel(idx));

    % --- per-run offset and dynamic EF
    m = numel(idx);
    efd = nan(m, 1);  hrRef = efd;  rmse = efd;  hrMean = efd;
    for q = 1:m
        s = runs{idx(q)};
        z = lag1(s.vg, M.T_hr);
        u = s.use;
        c = mean(s.h(u) - M.G*z(u) - M.drift*s.t(u)/3600);
        res = s.h(u) - (c + M.G*z(u) + M.drift*s.t(u)/3600);
        hrRef(q) = c + M.G*p.vRef + M.drift*p.tRefMin/60;
        efd(q)   = p.vRef*60 / (hrRef(q) - cfg.athlete.HRrest);
        rmse(q)  = sqrt(mean(res.^2));
        hrMean(q) = mean(s.h(u));
    end
    T = table(A.day(idx), efd, hrRef, rmse, hrMean, ...
        'VariableNames', {'day', 'ef_dyn', 'hr_ref', 'rmse', 'hr_mean'});
end

function [h, vg, tt] = prepare_run(r)
% 1 Hz grid, grade-adjusted speed (5 s smoothing, Minetti), elapsed seconds
    ts = seconds(r.t - r.t(1));
    [ts, iu] = unique(ts);
    tt = (0:floor(ts(end)))';
    h = interp_ok(ts, r.hr(iu), tt);
    v = interp_ok(ts, r.speed(iu), tt);
    a = interp_ok(ts, r.alt(iu), tt);
    d = interp_ok(ts, r.dist(iu), tt);
    if all(isnan(h)) || all(isnan(v)), h = []; vg = []; return; end
    if all(isnan(a)), a = zeros(size(tt)); end
    dd = gradient(movmean(d, 30, 'omitnan'));
    da = gradient(movmean(a, 30, 'omitnan'));
    gr = zeros(size(tt));
    mv = dd > 0.5;
    gr(mv) = da(mv) ./ dd(mv);
    gr = min(max(gr, -0.15), 0.15);  gr(isnan(gr)) = 0;
    vg = movmean(v, 5, 'omitnan') .* minetti_cost(gr) ./ minetti_cost(0);
end

function y = interp_ok(t, x, tg)
    ok = ~isnan(x);
    if nnz(ok) < 10, y = nan(size(tg)); return; end
    y = interp1(t(ok), x(ok), tg, 'linear', 'extrap');
end

function z = lag1(v, Thr)
% first-order lag, unit gain, sampled at 1 s: z[k] = a z[k-1] + (1-a) v[k-1], z[1] = v[1]
    a = exp(-1/Thr);
    u = [v(1); v(1:end-1)];
    z = filter(1 - a, [1, -a], u, a*v(1));
end
