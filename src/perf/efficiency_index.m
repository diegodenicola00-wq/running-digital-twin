function m = efficiency_index(rec, cfg)
%EFFICIENCY_INDEX Aerobic efficiency of one run: grade-adjusted speed per net heartbeat.
%
%   m = efficiency_index(rec, cfg)
%
%   EF = mean(GAP speed) [m/min] / mean(HR - HRrest) [bpm]   ->  metres per net beat
%
% Rationale: at submaximal intensity speed (~ oxygen uptake) grows roughly
% linearly with HR above rest. If you get fitter, you run faster for the same
% number of net beats, so EF increases.
%
% Steps
%   1. resample to a 1 Hz grid, 30 s moving means of speed, HR, distance, altitude
%   2. grade-adjusted speed (GAP) with the Minetti et al. (2002) energy-cost curve
%   3. analysis window: from minute cfg.perf.skipMin (warm-up, optical-HR lag)
%      to minute cfg.perf.maxMin (fixed length -> cardiac drift comparable
%      between runs of different duration); running samples only
%   4. steady samples: GAP within +-cfg.perf.steadyTol of the window median
%
% Output struct m (NaN fields if the run is too short):
%   ef          metres per net beat
%   gap_kmh     mean grade-adjusted speed in the steady samples [km/h]
%   hr          mean HR in the steady samples [bpm]
%   hrr         mean HR-reserve fraction (HR-HRrest)/(HRmax-HRrest)
%   cv          coefficient of variation of the 60 s GAP in the window
%   steadyFrac  share of window samples classified as steady
%   winMin      length of the analysis window [min]

    m = struct('ef', NaN, 'gap_kmh', NaN, 'hr', NaN, 'hrr', NaN, ...
               'cv', NaN, 'steadyFrac', NaN, 'winMin', 0);
    p = cfg.perf;

    % --- 1. 1 Hz grid ------------------------------------------------------
    ts = seconds(rec.t - rec.t(1));
    [ts, iu] = unique(ts);
    tg = (0:floor(ts(end)))';
    if numel(tg) < p.minWinMin*60, return; end

    hr  = resample1(ts, rec.hr(iu),    tg);
    v   = resample1(ts, rec.speed(iu), tg);
    alt = resample1(ts, rec.alt(iu),   tg);
    d   = resample1(ts, rec.dist(iu),  tg);
    if all(isnan(hr)) || all(isnan(v)), return; end

    vs = movmean(v,  30, 'omitnan');
    hs = movmean(hr, 30, 'omitnan');

    % --- 2. grade-adjusted speed ----------------------------------------------
    if all(isnan(alt)) || all(isnan(d))
        grade = zeros(size(tg));
    else
        dd = gradient(movmean(d,   30, 'omitnan'));   % m per s
        da = gradient(movmean(alt, 30, 'omitnan'));
        grade = zeros(size(tg));
        moving = dd > 0.5;
        grade(moving) = da(moving) ./ dd(moving);
        grade = min(max(grade, -0.15), 0.15);
        grade(isnan(grade)) = 0;
    end
    gap = vs .* minetti_cost(grade) ./ minetti_cost(0);

    % --- 3. analysis window ---------------------------------------------------
    el  = tg / 60;                                     % elapsed minutes
    win = el >= p.skipMin & el <= min(p.maxMin, el(end) - 1) ...
          & vs > p.minSpeed & ~isnan(hs);
    if nnz(win) < p.minWinMin*60, return; end

    % --- 4. steady samples ----------------------------------------------------
    med    = median(gap(win));
    steady = win & abs(gap - med) < p.steadyTol * med;
    g60    = movmean(gap, 60, 'omitnan');

    HRrest = cfg.athlete.HRrest;
    m.gap_kmh    = mean(gap(steady)) * 3.6;
    m.hr         = mean(hs(steady));
    m.hrr        = (m.hr - HRrest) / (cfg.athlete.HRmax - HRrest);
    m.ef         = mean(gap(steady)) * 60 / (m.hr - HRrest);
    m.cv         = std(g60(win)) / mean(gap(win));
    m.steadyFrac = nnz(steady) / nnz(win);
    m.winMin     = nnz(win) / 60;
end

function y = resample1(t, x, tg)
    ok = ~isnan(x);
    if nnz(ok) < 10
        y = nan(size(tg));
    else
        y = interp1(t(ok), x(ok), tg, 'linear', 'extrap');
    end
end
