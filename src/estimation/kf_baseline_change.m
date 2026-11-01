function R = kf_baseline_change(w, kMeas, y, nMeas, par, kFix)
%KF_BASELINE_CHANGE Change of the aerobic baseline b since day kFix (fixed-point smoother).
%
%   R = kf_baseline_change(w, kMeas, y, nMeas, par, kFix)
%
% Same model and parameters as kf_banister.m, with the state augmented by a
% frozen copy of the baseline taken on day kFix:
%
%   z = [x1; x2; b; bFix],   bFix[k+1] = bFix[k]  (no process noise)
%
% On day kFix the copy is initialised with the current b and its covariance
% (bFix = b, same row/column of P). Every later measurement updates the copy
% through its correlation with b, so at the end bFix is the SMOOTHED estimate of
% b on day kFix given all the data, and the covariance of (b - bFix) is exact:
% this is a fixed-point smoother obtained with a plain Kalman filter.
%
% Output R: bEnd, bFix (estimates), d = bEnd - bFix, sd (its std), g = d/bFix
% (relative change), sdg (its std), kLast (index of the last measurement used).

    w = w(:);
    N = numel(w);
    A = diag([exp(-1/par.tau1), exp(-1/par.tau2), 1, 1]);
    B = [1; 1; 0; 0];
    C = [par.c1, par.c2, 1, 0];

    yDay = nan(N, 1);  yDay(kMeas) = y;
    nDay = zeros(N, 1);  nDay(kMeas) = nMeas;

    z = [0; 0; par.b0; 0];
    P = diag([par.Px0(1)^2, par.Px0(2)^2, par.Pb0, 0]);

    for k = 1:N
        if k == kFix                         % freeze a copy of b (before the update of day k)
            z(4) = z(3);
            P(4, :) = P(3, :);  P(:, 4) = P(:, 3);  P(4, 4) = P(3, 3);
        end
        if ~isnan(yDay(k))
            S = C*P*C' + par.sigma^2 / nDay(k);
            K = P*C' / S;
            z = z + K*(yDay(k) - C*z);
            P = (eye(4) - K*C) * P;
            P = (P + P') / 2;
        end
        Q = zeros(4);
        Q(1:2, 1:2) = (par.rho * w(k))^2;
        Q(3, 3) = par.qb;
        z = A*z + B*w(k);
        P = A*P*A' + Q;
    end

    v = [0 0 1 -1];
    R.bEnd  = z(3);
    R.bFix  = z(4);
    R.d     = v*z;
    R.sd    = sqrt(v*P*v');
    R.g     = R.d / R.bFix;
    R.sdg   = R.sd / R.bFix;
    R.kLast = max(kMeas(kMeas <= N));
end
