function [w, info] = taper_lp(dHist, wHist, raceDay, lim, P, mode)
%TAPER_LP Optimal training load from the day after dHist(end) to the day before the race.
%
%   [w, info] = taper_lp(dHist, wHist, raceDay, lim, P, mode)
%
% Banister model: the load of day d enters the states of race day with weight
% a^(m-1), m = days from d to the race, so performance on race day is LINEAR in
% the future loads w:
%
%   p_s(w) = c_s + f_s' * w,   f_s(d) = k1*a1^(m-1) - k2_s*a2_s^(m-1)
%
% (c_s: contribution of the past load). With linear constraints this is a linear
% program, solved with linprog (Optimization Toolbox).
%
%   mode = 'nominal'  maximise p for the nominal parameters (P.k2, P.tau2)
%   mode = 'robust'   maximise the WORST CASE, over all scenarios s
%                     (P.scenK2 x P.scenTau2), of p_s(w) / p_s*, where p_s* is the
%                     best performance achievable in scenario s (epigraph form):
%                     max t  s.t.  t <= (c_s + f_s' w) / p_s*  for every s
%
% Constraints (lim from taper_limits):
%   run days only (P.runDays), minFrac*ref(j) <= w <= cap(j) on session type j,
%   sessions fixed by the athlete: w = P.fixedKm * rate on the days P.fixedDays,
%   weekly load (Mon-Sun, including the days already done) <= lim.weekCap.
%
% Outputs
%   w      planned load, one value per day of info.days (0 on rest days)
%   info   days, type (session index, 0 = rest), lb, ub, fixed, F (S x n), c (S x 1),
%          pStar (S x 1), rel (S x 1, p_s(w)/p_s*), scen (S x 2: k2, tau2), iNom

    if ~exist('linprog', 'file')
        error('taper_lp: linprog not found. Install the Optimization Toolbox (included in the Polimi campus license).');
    end
    start = dHist(end) + caldays(1);
    H = (start : caldays(1) : raceDay - caldays(1))';
    n = numel(H);
    if n < 1, error('taper_lp: the race is not after the last day of history.'); end

    % --- bounds: session type of every day
    type = zeros(n, 1);
    for j = 1:numel(P.runDays)
        type(weekday(H) == P.runDays(j)) = j;
    end
    lb = zeros(n, 1);  ub = zeros(n, 1);
    on = type > 0;
    lb(on) = P.minFrac * lim.ref(type(on))';
    ub(on) = lim.cap(type(on))';

    % --- sessions fixed by the athlete (lb = ub)
    fixed = false(n, 1);
    for q = 1:numel(P.fixedDays)
        i = find(H == dateshift(P.fixedDays(q), 'start', 'day'));
        if isempty(i), continue; end                     % already done or after the race
        if type(i) == 0
            error('taper_lp: fixed day %s is not a run day.', datestr(H(i)));
        end
        lb(i) = P.fixedKm(q) * lim.rate(type(i));
        ub(i) = lb(i);
        fixed(i) = true;
    end

    % --- weekly constraints (Mon-Sun), load already done in the same week subtracted
    wkH = week_id(H);  wkP = week_id(dHist);
    ids = unique(wkH);
    A = zeros(numel(ids), n);  b = zeros(numel(ids), 1);
    for q = 1:numel(ids)
        A(q, :) = (wkH == ids(q))';
        b(q) = lim.weekCap - sum(wHist(wkP == ids(q)));
        b(q) = max(b(q), A(q, :) * lb);        % never infeasible: minimum sessions allowed
    end

    % --- scenarios
    [K2, T2] = meshgrid(P.scenK2, P.scenTau2);
    scen = [K2(:), T2(:)];
    iNom = find(scen(:, 1) == P.k2 & scen(:, 2) == P.tau2, 1);
    if isempty(iNom), error('taper_lp: the nominal (k2, tau2) must be one of the scenarios.'); end
    S = size(scen, 1);
    mF = days(raceDay - H);          % future days
    mH = days(raceDay - dHist);      % past days
    a1 = exp(-1/P.tau1);
    F = zeros(S, n);  c = zeros(S, 1);  pStar = zeros(S, 1);
    opt = optimoptions('linprog', 'Display', 'none');
    for s = 1:S
        a2 = exp(-1/scen(s, 2));
        F(s, :) = (P.k1 * a1.^(mF - 1) - scen(s, 1) * a2.^(mF - 1))';
        c(s)    = P.k1 * sum(a1.^(mH - 1) .* wHist) - scen(s, 1) * sum(a2.^(mH - 1) .* wHist);
        [ws, ~, flag] = linprog(-F(s, :)', A, b, [], [], lb, ub, opt);
        if flag ~= 1, error('taper_lp: linprog failed (scenario %d, flag %d).', s, flag); end
        pStar(s) = c(s) + F(s, :) * ws;
        if s == iNom, wNom = ws; end
    end

    switch mode
        case 'nominal'
            w = wNom;
        case 'robust'
            % variables [w; t]: maximise t
            fobj = [zeros(n, 1); -1];
            Ar = [A, zeros(size(A, 1), 1);
                  -F ./ pStar, ones(S, 1)];
            br = [b; c ./ pStar];
            [z, ~, flag] = linprog(fobj, Ar, br, [], [], [lb; -Inf], [ub; Inf], opt);
            if flag ~= 1, error('taper_lp: robust linprog failed (flag %d).', flag); end
            w = z(1:n);
        otherwise
            error('taper_lp: unknown mode "%s".', mode);
    end
    w(abs(w) < 1e-6) = 0;

    info = struct('days', H, 'type', type, 'lb', lb, 'ub', ub, 'fixed', fixed, 'F', F, 'c', c, ...
        'pStar', pStar, 'rel', (c + F*w) ./ pStar, 'scen', scen, 'iNom', iNom);
end

function id = week_id(d)
% Monday-based week number (3 Jan 2000 was a Monday).
    id = floor(days(d - datetime(2000, 1, 3)) / 7);
end
