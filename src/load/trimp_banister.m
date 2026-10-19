function [trimp, info] = trimp_banister(t, hr, cfg)
%TRIMP_BANISTER Banister training impulse from a 1 Hz heart-rate series.
%
%   [trimp, info] = trimp_banister(t, hr, cfg)
%
%   TRIMP = sum_i  dt_i[min] * HRr_i * a * exp(b * HRr_i)
%   HRr   = (HR - HRrest) / (HRmax - HRrest)      heart-rate reserve fraction
%   a, b  = 0.64, 1.92 (male)  |  0.86, 1.67 (female)    (Banister, 1991)
%
% Integrated sample by sample (not from average HR): because of the
% exponential weighting, TRIMP(mean HR) underestimates interval sessions.
%
% Cleaning
%   - samples with HR < cfg.clean.hrMin or NaN are skipped (sensor dropouts)
%   - gaps longer than cfg.clean.maxGap seconds are not integrated (pauses)
%
% info.validFraction  share of the session duration with usable HR
%                     (low values flag a bad optical-HR recording)

    HRmax  = cfg.athlete.HRmax;
    HRrest = cfg.athlete.HRrest;
    if upper(cfg.athlete.sex) == 'F', a = 0.86; b = 1.67;
    else,                             a = 0.64; b = 1.92; end

    hr = hr(:);
    dt = [seconds(diff(t(:))); 0];             % time until the next sample [s]
    dt(dt > cfg.clean.maxGap | dt < 0) = 0;

    valid = ~isnan(hr) & hr >= cfg.clean.hrMin;
    HRr   = min(max((hr - HRrest) / (HRmax - HRrest), 0), 1);

    w     = dt / 60 .* HRr .* a .* exp(b * HRr);
    trimp = sum(w(valid));

    info.duration      = sum(dt);              % [s] moving/recorded time
    info.validFraction = sum(dt(valid)) / max(sum(dt), eps);
end
