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

    % --- identification (Step 3) -------------------------------------------------
    cfg.id.tau1Grid = 5:1:150;                    % [days] fitness time constant grid
    cfg.id.tau2Grid = 1:0.5:40;                   % [days] fatigue time constant grid
    cfg.id.valStart = datetime(2026, 8, 17);      % validation: fit before, predict after

    % --- dynamic EF: pooled first-order HR model (Step 3) ---------------------------
    cfg.dyn.skipSec    = 180;                     % [s]   skip the first minutes of each run
    cfg.dyn.minSamples = 600;                     % [s]   minimum usable samples per run
    cfg.dyn.maxMeanHR  = 175;                     % [bpm] runs above: near-maximal, excluded
    cfg.dyn.Tgrid      = [30 40 50 60 70 80 100]; % [s]   grid of the HR time constant
    cfg.dyn.vRef       = 3.0;                     % [m/s] reference speed (10.8 km/h)
    cfg.dyn.tRefMin    = 20;                      % [min] reference time (for the drift)

    % --- Kalman filter (Step 4) ------------------------------------------------------
    % States: x1 fitness, x2 fatigue (literature time constants, Step 3 decision),
    % b aerobic baseline (random walk). Measurement: dynamic EF = b + c1*x1 + c2*x2 + v.
    % c1 = 0: fitness is not observable from the HR-based EF (Step 3, t ~ 0).
    % c2, qb, rho: maximum likelihood on the innovations, idStart .. valStart-1.
    cfg.kf.tau1     = 42;                         % [days] fitness  (literature)
    cfg.kf.tau2     = 7;                          % [days] fatigue  (literature)
    cfg.kf.c1       = 0;                          % [-]    fitness -> EF (not observable)
    cfg.kf.c2Grid   = 0:1e-4:1.2e-3;              % [m/beat per TRIMP] fatigue -> EF
    cfg.kf.qbGrid   = [0 3e-6 1e-5 2e-5 3e-5 5e-5 1e-4 3e-4];  % [(m/beat)^2/day] baseline drift
    cfg.kf.rhoGrid  = [0 0.1 0.2 0.5];            % [-]    relative error of the daily TRIMP
    cfg.kf.Px0      = [300 100];                  % [TRIMP] std of x1, x2 on 1 Nov 2025 (unknown past)
    cfg.kf.Pb0      = 0.1^2;                      % [(m/beat)^2] variance of the initial baseline
    cfg.kf.nInit    = 5;                          % [-]    first measurements used for the initial baseline

    % --- Taper planning, MPC (Step 5) -------------------------------------------------
    % Decision: TRIMP of every session from the plan start to the day before the race.
    % Objective: performance on race day, p = k1*x1 - k2*x2 (literature model).
    % Constraints from the athlete's own recent training (no new records before a race):
    % session load <= max of the same session in the last capWeeks weeks, weekly load
    % (Mon-Sun) <= max week of the last weekCapWeeks weeks, every session >= minFrac
    % of its usual load (keep the frequency during the taper, Mujika & Padilla 2003).
    cfg.mpc.runDays     = [1 3 5];                 % weekday(): 1 = Sun, 3 = Tue, 5 = Thu
    cfg.mpc.sessionName = ["long", "easy", "quality"];   % same order as runDays
    cfg.mpc.planStart   = [];                      % [] = today, or the day after the last run
    cfg.mpc.tau1        = 42;                      % [days] fitness (literature)
    cfg.mpc.k1          = 1;                       % [-]    fitness gain (only k2/k1 matters)
    cfg.mpc.k2          = 2;                       % [-]    nominal fatigue gain (literature)
    cfg.mpc.tau2        = 7;                       % [days] nominal fatigue time constant
    cfg.mpc.minFrac     = 0.5;                     % [-]    min session load / usual load
    cfg.mpc.capWeeks    = 8;                       % [weeks] window for session caps and usual loads
    cfg.mpc.weekCapWeeks = 12;                     % [weeks] window for the weekly cap
    cfg.mpc.maxDataAge  = 3;                       % [days] warn if the last run is older than this
    % sessions fixed by the athlete (km at the usual intensity of that session); the
    % optimiser plans the others around them. 15 Nov: last long run before the race,
    % 12 km by choice (specific endurance is not in the model; cost in results_log).
    % 1 Nov: no run (the long run was moved to Sat 31 Oct).
    cfg.mpc.fixedDays   = [datetime(2026, 11, 1), datetime(2026, 11, 15)];
    cfg.mpc.fixedKm     = [0, 12];                 % [km]
    % athlete's own plan (results/athlete_plan.csv), evaluated with the same model.
    % TRIMP per km: easy from the athlete's easy runs (median 8.7); half-marathon pace
    % (~4:30/km, ~178 bpm) and threshold (~4:20/km, ~183 bpm) from the TRIMP formula.
    cfg.mpc.rate.easy      = 8.5;                  % [TRIMP/km]
    cfg.mpc.rate.hm        = 12.8;                 % [TRIMP/km]
    cfg.mpc.rate.threshold = 13.6;                 % [TRIMP/km]
    % robust plan: worst case over these scenarios of the uncertain fatigue parameters
    cfg.mpc.scenK2      = [1.5 2 3];               % [-]    k2/k1
    cfg.mpc.scenTau2    = [5 7 10];                % [days] tau2
    % closed-loop simulation (receding horizon)
    cfg.mpc.replanDays  = 7;                       % [days] re-plan every week
    cfg.mpc.nMC         = 100;                     % [-]    Monte Carlo runs
    cfg.mpc.loadStd     = 0.15;                    % [-]    relative error executing a session
    cfg.mpc.pMiss       = 0.10;                    % [-]    probability of skipping a session
    cfg.mpc.seed        = 1;

    % --- Pre-registered race prediction (Step 6) -----------------------------------
    % Method fixed BEFORE the race (see main_06_prediction.m): Riegel from the 10 km
    % race, adjusted by the change of the aerobic baseline (Kalman) since that race.
    cfg.pred.anchorDate = datetime(2026, 9, 27);   % 10 km race
    cfg.pred.anchorDist = 10;                      % [km]
    cfg.pred.anchorTime = 40*60 + 59;              % [s]  40:59
    cfg.pred.raceDist   = 21.0975;                 % [km]
    cfg.pred.eCentral   = 1.06;                    % [-]  Riegel exponent (Riegel 1981)
    cfg.pred.eRange     = [1.04 1.08];             % [-]  uniform range of the exponent
    cfg.pred.nMC        = 1e5;                     % [-]  Monte Carlo samples
    cfg.pred.interval   = [10 90];                 % [%]  percentiles of the interval
    cfg.pred.seed       = 1;

    % --- Race result and post-race checks (Step 6, after 22 Nov 2026) --------------
    % The sensitivity checks below were registered BEFORE the race (results_log, 20 Nov).
    cfg.race.chipTime    = 1*3600 + 34*60 + 12;    % [s]  official chip time 1:34:12
    cfg.race.predCentral = 1*3600 + 34*60 + 8;     % [s]  pre-registered central prediction (commit 580331d)
    cfg.race.predCutoff  = datetime(2026, 11, 19); % last measurement used by the prediction
    cfg.race.preTaperEnd = datetime(2026, 11, 8);  % last measurement before the taper

    % --- Phase 2: morning HRV (HRM 600 chest strap, HRV Logger) -------------------
    % Rules fixed on 23 Nov 2026, before the series is collected (main_08_hrv.m).
    cfg.hrv.dir        = fullfile(root, 'data', 'raw', 'hrv');
    cfg.hrv.strapStart = datetime(2026, 11, 23);   % first day with the chest strap
    cfg.hrv.morning    = [4 12];                   % [h]  a morning session starts in this range
    cfg.hrv.skip       = 60;                       % [s]  settling time dropped at the start
    cfg.hrv.rrMin      = 300;                      % [ms] plausible RR range
    cfg.hrv.rrMax      = 2000;                     % [ms]
    cfg.hrv.medWin     = 11;                       % [beats] window of the local median
    cfg.hrv.artTol     = 0.25;                     % [-]  artifact if |rr - median| > 25 %
    cfg.hrv.minDur     = 180;                      % [s]  minimum analysed time
    cfg.hrv.maxArt     = 0.05;                     % [-]  maximum artifact fraction
end
