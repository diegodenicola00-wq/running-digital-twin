function C = minetti_cost(i)
%MINETTI_COST Energy cost of running vs gradient [J/(kg*m)].
%
%   C = minetti_cost(i)      i = gradient as a fraction (0.05 = 5%), valid ~[-0.45, 0.45]
%
% Minetti A.E. et al. (2002), "Energy cost of walking and running at extreme
% uphill and downhill slopes", J Appl Physiol 93(3):1039-1046.
% Used to convert speed on a slope into the equivalent speed on the flat:
%   GAP = v * C(i) / C(0)

    C = 155.4*i.^5 - 30.4*i.^4 - 43.3*i.^3 + 46.3*i.^2 + 19.5*i + 3.6;
end
