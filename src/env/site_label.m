function site = site_label(lat, lon, cfg)
%SITE_LABEL Name of the known place closest to each run start ("other" if none).
%
%   site = site_label(lat, lon, cfg)
%
% Known places and the matching radius are defined in cfg.sites.
% Distance: equirectangular approximation (fine for a few tens of km).

    R = 6371;                                        % Earth radius [km]
    n = numel(lat);
    site = repmat("other", n, 1);
    site(isnan(lat) | isnan(lon)) = "no GPS";
    best = inf(n, 1);
    for k = 1:numel(cfg.sites.name)
        x = deg2rad(lon - cfg.sites.lon(k)) .* cos(deg2rad(cfg.sites.lat(k)));
        y = deg2rad(lat - cfg.sites.lat(k));
        d = R * sqrt(x.^2 + y.^2);
        hit = d < cfg.sites.radiusKm & d < best;
        site(hit) = cfg.sites.name(k);
        best(hit) = d(hit);
    end
    site = categorical(site);
end
