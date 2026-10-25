function R = varpro_banister(w, kIdx, y, tau1Grid, tau2Grid)
%VARPRO_BANISTER Fit the Banister model by variable projection on a grid.
%
%   R = varpro_banister(w, kIdx, y, tau1Grid, tau2Grid)
%
%   p[k] = p0 + k1*x1[k] - k2*x2[k],  x_i = banister_states(w, tau_i)
%
% The model is nonlinear in (tau1, tau2) but LINEAR in (p0, k1, k2): for every
% pair of time constants on the grid the gains are found by linear least
% squares, and the pair with the lowest residual sum of squares is kept
% (global minimum on the grid, no starting point needed).
%
% Inputs
%   w         daily load (whole series, from the start of the burn-in)
%   kIdx      day index (1-based) of each measurement
%   y         measurements (same length as kIdx)
%   tau1Grid, tau2Grid   grids of time constants [days], tau2 < tau1 enforced
%
% Output struct R
%   J          RSS map (numel(tau1Grid) x numel(tau2Grid)), NaN where tau2 >= tau1
%   tau1, tau2 best time constants;  theta = [p0; k1; k2]
%   rss, n, R2, AIC, AICconst
%   region95   logical map of the approximate 95 % joint confidence region of
%              (tau1, tau2):  RSS <= RSSmin * (1 + 2/(n-5) * F(0.95; 2, n-5))
%   tau1Range, tau2Range   extent of that region

    y = y(:);  kIdx = kIdx(:);  n = numel(y);
    X1 = zeros(n, numel(tau1Grid));  X2 = zeros(n, numel(tau2Grid));
    for i = 1:numel(tau1Grid)
        x = banister_states(w, tau1Grid(i));  X1(:, i) = x(kIdx);
    end
    for j = 1:numel(tau2Grid)
        x = banister_states(w, tau2Grid(j));  X2(:, j) = x(kIdx);
    end

    J = nan(numel(tau1Grid), numel(tau2Grid));
    one = ones(n, 1);
    for i = 1:numel(tau1Grid)
        for j = 1:numel(tau2Grid)
            if tau2Grid(j) >= tau1Grid(i), continue; end
            X = [one, X1(:, i), -X2(:, j)];
            r = y - X * (X \ y);
            J(i, j) = r' * r;
        end
    end

    [rss, idx] = min(J(:));
    [i, j] = ind2sub(size(J), idx);
    X = [one, X1(:, i), -X2(:, j)];
    rss0 = sum((y - mean(y)).^2);

    R.J = J;  R.tau1Grid = tau1Grid;  R.tau2Grid = tau2Grid;
    R.tau1 = tau1Grid(i);  R.tau2 = tau2Grid(j);
    R.theta = X \ y;
    R.rss = rss;  R.n = n;
    R.R2 = 1 - rss / rss0;
    R.AIC = n * log(rss / n) + 2 * 5;
    R.AICconst = n * log(rss0 / n) + 2 * 1;
    R.region95 = J <= rss * (1 + 2 / (n - 5) * finv_base(0.95, 2, n - 5));
    R.tau1Range = [min(tau1Grid(any(R.region95, 2))), max(tau1Grid(any(R.region95, 2)))];
    R.tau2Range = [min(tau2Grid(any(R.region95, 1))), max(tau2Grid(any(R.region95, 1)))];
end

function f = finv_base(p, d1, d2)
% F-distribution quantile with base MATLAB only (no Statistics Toolbox)
    x = betaincinv(p, d1/2, d2/2);
    f = d2 * x / (d1 * (1 - x));
end
