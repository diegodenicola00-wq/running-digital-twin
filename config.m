function cfg = config()
%CONFIG Athlete and pipeline parameters (single source of truth).

    root = fileparts(mfilename('fullpath'));

    % --- paths ---------------------------------------------------------
    cfg.paths.root      = root;
    cfg.paths.fit       = fullfile(root, 'data', 'raw', 'fit');
    cfg.paths.csv       = fullfile(root, 'data', 'interim', 'csv');
    cfg.paths.processed = fullfile(root, 'data', 'processed');
    cfg.paths.results   = fullfile(root, 'results');
    cfg.paths.fitcsvtool = fullfile(root, 'tools', 'FitCSVTool.jar');

    % --- athlete -------------------------------------------------------
    % HRmax: highest reliable value observed (10 km race, 27 Sep 2026: 200 bpm).
    % HRrest: Garmin 7-day average resting HR, Oct 2026 (44-46 bpm).
    cfg.athlete.HRmax  = 200;   % [bpm]
    cfg.athlete.HRrest = 45;    % [bpm]
    cfg.athlete.timezone = 'Europe/Rome';   % used to assign runs to calendar days
    cfg.athlete.sex    = 'M';   % TRIMP weighting coefficient depends on it

    % --- devices --------------------------------------------------------
    % Wrist optical HR only (no chest strap ever used).
    %   Garmin Vivoactive 4S       until 2025-11-02
    %   Garmin Instinct 2 Solar    from  2025-11-03
    cfg.device.change = datetime(2025, 11, 3);   % data before this: different sensor

    % --- analysis windows ------------------------------------------------
    % dataStart: Nov 2025 -> Feb 2026 is pure burn-in for the model states
    % (unstructured running, but load is load). The effect of the unknown
    % initial state decays as exp(-t/tau1): ~6% after 4 months with tau1 = 42 d.
    cfg.dates.dataStart  = datetime(2025, 11, 1);
    cfg.dates.idStart    = datetime(2026, 3, 1);    % earliest date usable for identification
    cfg.dates.planStart  = datetime(2026, 8, 17);   % structured plan begins
    cfg.dates.race10k    = datetime(2026, 9, 27);
    cfg.dates.raceHalf   = datetime(2026, 11, 22);

    % --- data cleaning -------------------------------------------------
    cfg.clean.hrMin   = 60;    % [bpm] samples below are treated as dropouts
    cfg.clean.maxGap  = 10;    % [s]   longer gaps are not integrated (pauses)

    % --- performance index (Step 2) ----------------------------------------
    % Thresholds chosen on a 19-run prototype (21 Oct 2026, notes/results_log.md).
    cfg.perf.skipMin   = 10;    % [min] skip warm-up and optical-HR lag
    cfg.perf.maxMin    = 45;    % [min] fixed window end -> comparable cardiac drift
    cfg.perf.minWinMin = 15;    % [min] minimum usable window
    cfg.perf.minSpeed  = 2.0;   % [m/s] below = walking / stopped
    cfg.perf.steadyTol = 0.15;  % [-]   steady sample: GAP within +-15% of the median
    % selection of runs used as performance measurements
    cfg.perf.maxCV     = 0.10;  % [-]   pace variability (intervals: CV > 0.2)
    cfg.perf.minSteady = 0.70;  % [-]   share of steady samples (0.6-0.7: same noise, +2 runs; see results_log)
    cfg.perf.maxHRR    = 0.75;  % [-]   HR-reserve fraction (easy runs; HR <= ~161 bpm)
    % heat effect (within-season comparison)
    cfg.perf.trendRuns = 9;     % [runs]  local running median removed before regressing on temperature
    cfg.perf.refTemp   = 15;    % [degC]  EF corrected to this reference temperature

    % --- places where the athlete runs ------------------------------------------
    % L'Aquila: ~600-720 m a.s.l., hilly; summer 2026 (3 Jul - 12 Sep) and other periods.
    cfg.sites.name     = ["Milano", "L'Aquila"];
    cfg.sites.lat      = [45.49, 42.35];
    cfg.sites.lon      = [ 9.19, 13.40];
    cfg.sites.radiusKm = 30;
end
