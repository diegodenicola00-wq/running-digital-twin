function W = get_weather(A, cfg)
%GET_WEATHER Air temperature and humidity at the place and time of every run.
%
%   W = get_weather(A, cfg)
%
% A: activity table from main_01_pipeline (needs start, dur_min, lat, lon).
% W: table with one row per run: temp [degC], rh [%], app_temp [degC]
%    (apparent temperature: heat + humidity + wind), NaN if not available.
%
% Source: Open-Meteo historical weather API (ERA5 reanalysis, hourly, no API key).
%   Zippenfenig, P. (2023). Open-Meteo.com Weather API. Zenodo.
%   doi:10.5281/ZENODO.7970649
%   Hersbach, H. et al. (2023). ERA5 hourly data on single levels. doi:10.24381/cds.adbb2d47
%
% Runs are grouped by location (coordinates rounded to 0.1 deg, ~10 km): one
% request per location for the whole period, cached in data/interim/weather/.
% Each run gets the weather interpolated at its mid-time.

    cacheDir = fullfile(cfg.paths.root, 'data', 'interim', 'weather');
    if ~isfolder(cacheDir), mkdir(cacheDir); end

    n = height(A);
    W = table(nan(n,1), nan(n,1), nan(n,1), 'VariableNames', {'temp','rh','app_temp'});

    tMid = A.start + minutes(A.dur_min / 2);
    tMid.TimeZone = 'UTC';

    key = round([A.lat A.lon] * 10) / 10;           % ~10 km grid
    ok  = all(~isnan(key), 2);                      % treadmill runs have no GPS
    [sites, ~, idx] = unique(key(ok, :), 'rows');
    okIdx = find(ok);

    d0 = datestr(cfg.dates.dataStart, 'yyyy-mm-dd');
    d1 = datestr(datetime('today') - days(1), 'yyyy-mm-dd');

    for s = 1:size(sites, 1)
        lat = sites(s, 1);  lon = sites(s, 2);
        cacheFile = fullfile(cacheDir, sprintf('wx_%+.1f_%+.1f.mat', lat, lon));
        H = [];
        if isfile(cacheFile)
            C = load(cacheFile, 'H');
            H = C.H;
            if max(H.time) < datetime(d1, 'TimeZone', 'UTC') - days(7)
                H = [];                             % stale cache: refresh
            end
        end
        if isempty(H)
            H = fetch_open_meteo(lat, lon, d0, d1);
            save(cacheFile, 'H');
            pause(1);                               % be gentle with the free API
        end

        runs = okIdx(idx == s);
        th = posixtime(H.time);
        tr = posixtime(tMid(runs));
        W.temp(runs)     = interp1(th, H.temp,     tr, 'linear', NaN);
        W.rh(runs)       = interp1(th, H.rh,       tr, 'linear', NaN);
        W.app_temp(runs) = interp1(th, H.app_temp, tr, 'linear', NaN);
        fprintf('  weather %+.1f, %+.1f: %d runs\n', lat, lon, numel(runs));
    end
end

function H = fetch_open_meteo(lat, lon, d0, d1)
    url = 'https://archive-api.open-meteo.com/v1/archive';
    opts = weboptions('Timeout', 60);
    r = webread(url, 'latitude', lat, 'longitude', lon, ...
        'start_date', d0, 'end_date', d1, ...
        'hourly', 'temperature_2m,relative_humidity_2m,apparent_temperature', ...
        'timezone', 'GMT', opts);
    time = datetime(r.hourly.time, 'InputFormat', 'yyyy-MM-dd''T''HH:mm', ...
                    'TimeZone', 'UTC');
    H = table(time(:), tonum(r.hourly.temperature_2m), ...
              tonum(r.hourly.relative_humidity_2m), ...
              tonum(r.hourly.apparent_temperature), ...
              'VariableNames', {'time','temp','rh','app_temp'});
end

function x = tonum(v)
% JSON nulls (most recent hours not yet in the archive) may come back as a cell
    if iscell(v)
        x = nan(numel(v), 1);
        for k = 1:numel(v)
            if isnumeric(v{k}) && ~isempty(v{k}), x(k) = v{k}; end
        end
    else
        x = double(v(:));
    end
end
