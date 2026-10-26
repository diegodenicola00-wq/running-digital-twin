function F = kf_banister(w, kMeas, y, nMeas, par)
%KF_BANISTER Kalman filter on the Banister states plus an aerobic baseline.
%
%   F = kf_banister(w, kMeas, y, nMeas, par)
%
% State  z = [x1; x2; b]   fitness, fatigue, aerobic baseline
%
%   z[k+1] = A z[k] + B w[k] + noise,   A = diag(a1, a2, 1),  B = [1; 1; 0]
%   y[k]   = C z[k] + v[k],             C = [c1, c2, 1]
%
%   a_i = exp(-1/tau_i). Process noise: relative error rho of the daily load
%   on x1 and x2 (the same error enters both), random walk qb on b.
%   Measurement noise: sigma^2 / (number of runs averaged on that day).
%
% Same time convention as banister_states.m: the state of day k contains the
% load of the days BEFORE k, so the measurement of day k is used first
% (update) and the load of day k is added afterwards (prediction).
%
% Inputs
%   w      daily load, N x 1
%   kMeas  day indices (1..N) with a measurement
%   y      measurements (mean dynamic EF of the day)
%   nMeas  number of runs averaged on each of those days
%   par    struct: tau1, tau2, c1, c2, qb, rho, sigma, b0, Pb0, Px0,
%          llStart, llEnd (day indices of the log-likelihood window)
%
% Output F (struct)
%   z, Pdiag   filtered state and its variances, N x 3 (after the update of day k)
%   yhat, e, S one-step-ahead prediction, innovation and its variance (NaN on
%              days without a measurement), N x 1
%   ll         log-likelihood of the innovations in [llStart, llEnd]
%   zNext, PNext   prediction for day N+1 (starting point for Step 5)

    w = w(:);
    N = numel(w);
    A = diag([exp(-1/par.tau1), exp(-1/par.tau2), 1]);
    B = [1; 1; 0];
    C = [par.c1, par.c2, 1];

    yDay = nan(N, 1);  yDay(kMeas) = y;
    nDay = zeros(N, 1);  nDay(kMeas) = nMeas;

    z = [0; 0; par.b0];
    P = diag([par.Px0(1)^2, par.Px0(2)^2, par.Pb0]);

    F.z = zeros(N, 3);  F.Pdiag = zeros(N, 3);
    F.yhat = nan(N, 1);  F.e = nan(N, 1);  F.S = nan(N, 1);
    ll = 0;

    for k = 1:N
        % --- measurement update
        if ~isnan(yDay(k))
            R = par.sigma^2 / nDay(k);
            F.yhat(k) = C*z;
            F.S(k)    = C*P*C' + R;
            F.e(k)    = yDay(k) - F.yhat(k);
            K = P*C' / F.S(k);
            z = z + K*F.e(k);
            P = (eye(3) - K*C) * P;
            P = (P + P') / 2;
            if k >= par.llStart && k <= par.llEnd
                ll = ll - 0.5*(log(2*pi*F.S(k)) + F.e(k)^2/F.S(k));
            end
        end
        F.z(k, :) = z';
        F.Pdiag(k, :) = diag(P)';

        % --- time update (load of day k)
        Q = zeros(3);
        Q(1:2, 1:2) = (par.rho * w(k))^2;
        Q(3, 3) = par.qb;
        z = A*z + B*w(k);
        P = A*P*A' + Q;
    end

    F.ll = ll;
    F.zNext = z;
    F.PNext = P;
end
