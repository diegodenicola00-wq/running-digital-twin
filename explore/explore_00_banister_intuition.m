%% EXPLORE_00_BANISTER_INTUITION  Play with the Banister model on synthetic data
%
% Goal: build intuition BEFORE touching real data. No Garmin data needed.
% Parameters are typical literature values, NOT yours (those come in phase 3).
%
%   x1[k+1] = a1*x1[k] + w[k]     a1 = exp(-1/tau1)   fitness
%   x2[k+1] = a2*x2[k] + w[k]     a2 = exp(-1/tau2)   fatigue
%   p[k]    = p0 + k1*x1[k] - k2*x2[k]                performance

clear; clc; close all;

tau1 = 42;  tau2 = 7;      % [days]
k1   = 1;   k2   = 2;      % [perf. units / TRIMP]
p0   = 0;

simulate = @(w) banister_sim(w, tau1, tau2, k1, k2, p0);

%% 1. Response to ONE session (impulse response)
N = 60;
w = zeros(N, 1);  w(1) = 100;          % a single hard session on day 1
[p, x1, x2] = simulate(w);

figure('Name', 'Impulse response');
plot(0:N-1, k1*x1, 0:N-1, -k2*x2, 0:N-1, p - p0, 'LineWidth', 1.5);
yline(0, ':');  grid on
legend('k_1 x_1 (fitness)', '-k_2 x_2 (fatigue)', 'net effect on performance');
xlabel('days after the session'); ylabel('performance units');
title('One session: first you get worse, then better');

%% 2. Twelve weeks of training + taper
% weekly pattern (Mon..Sun): rest, easy, intervals, easy, rest, easy, long run
week  = [0 60 110 60 0 60 150]';
nWeek = 12;
w = repmat(week, nWeek, 1);
taperDays = 10;
w(end-taperDays+1:end) = 0.4 * w(end-taperDays+1:end);   % -60% volume
w = [w; zeros(7, 1)];                                     % one week after

[p, x1, x2] = simulate(w);
[pBest, kBest] = max(p);

figure('Name', 'Training block');
subplot(2,1,1);
bar(w, 1, 'FaceColor', [0.7 0.7 0.7], 'EdgeColor', 'none');
ylabel('daily TRIMP'); grid on
title(sprintf('12-week block, last %d days at 40%% load', taperDays));
subplot(2,1,2);
plot(p, 'LineWidth', 1.5); hold on
plot(kBest, pBest, 'o', 'MarkerFaceColor', 'auto');
xline(nWeek*7, ':', 'end of block');
ylabel('performance'); xlabel('day'); grid on
fprintf('Performance peaks on day %d (block ends on day %d)\n', kBest, nWeek*7);

%% ---------------------------------------------------------------------
function [p, x1, x2] = banister_sim(w, tau1, tau2, k1, k2, p0)
    a1 = exp(-1/tau1);  a2 = exp(-1/tau2);
    N  = numel(w);
    x1 = zeros(N, 1);   x2 = zeros(N, 1);
    for k = 1:N-1
        x1(k+1) = a1*x1(k) + w(k);
        x2(k+1) = a2*x2(k) + w(k);
    end
    p = p0 + k1*x1 - k2*x2;
end
