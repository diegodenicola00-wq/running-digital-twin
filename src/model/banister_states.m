function x = banister_states(w, tau)
%BANISTER_STATES First-order state of the Banister model for a daily load series.
%
%   x = banister_states(w, tau)
%
%   x[k+1] = exp(-1/tau) * x[k] + w[k],   x[1] = 0
%
% w: daily load (column vector), tau: time constant [days].
% The state on day k contains the load of the days BEFORE k: the run that
% produces the measurement of day k has not had any effect yet.

    w = w(:);
    a = exp(-1/tau);
    x = filter(1, [1, -a], [0; w(1:end-1)]);
end
