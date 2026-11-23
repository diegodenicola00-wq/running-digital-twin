function M = hrv_session(S, H)
%HRV_SESSION  Morning HRV indices of one RR recording (rules fixed on 23 Nov 2026).
%
%   M = hrv_session(S, H)   S from read_hrvlogger_rr, H = cfg.hrv
%
%   1. The first H.skip seconds are dropped (settling after lying down).
%   2. A beat is an artifact if outside [H.rrMin, H.rrMax] ms or if it differs
%      from the median of the H.medWin beats around it by more than H.artTol.
%   3. rMSSD uses only successive differences where both beats are good.
%   4. The session is valid if at least H.minDur s remain and the artifact
%      fraction is at most H.maxArt.
%   The trend is followed on ln(rMSSD) (Plews et al. 2013).

rr = S.rr(:);  t = S.t(:);
med = movmedian(rr, H.medWin);
good = rr >= H.rrMin & rr <= H.rrMax & abs(rr - med) <= H.artTol * med;
use = t > H.skip;

d = diff(rr);
pair = good(1:end-1) & good(2:end) & use(2:end);

M.start   = S.start;
M.dur     = t(end) - H.skip;                     % [s] analysed time
M.nBeats  = sum(use);
M.artFrac = sum(use & ~good) / max(sum(use), 1);
M.hr      = 60000 / mean(rr(use & good));        % [bpm]
M.rmssd   = sqrt(mean(d(pair).^2));              % [ms]
M.lnRmssd = log(M.rmssd);
M.sdnn    = std(rr(use & good));                 % [ms]
M.valid   = M.dur >= H.minDur && M.artFrac <= H.maxArt;
M.repeats = S.nRaw - numel(S.rr);
end
