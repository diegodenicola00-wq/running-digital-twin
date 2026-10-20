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
end
