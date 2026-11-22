# Running Digital Twin

Data-driven modelling, state estimation and optimal control of endurance-training adaptation, built on my own Garmin data.

**Case study:** preparation for a half marathon on 22 November 2026 (structured plan started 17 August 2026).

## Idea

The athlete is treated as a dynamic system:

- **input** `w[k]`: daily training load (TRIMP, computed from raw heart-rate data)
- **states** `x1[k]` fitness, `x2[k]` fatigue (not directly measurable)
- **output** `p[k]`: performance (aerobic-efficiency index from easy runs + race results)

Banister impulse-response model, discretised on a daily grid:

```
x1[k+1] = exp(-1/tau1) * x1[k] + w[k]
x2[k+1] = exp(-1/tau2) * x2[k] + w[k]
p[k]    = p0 + k1*x1[k] - k2*x2[k]
```

## Roadmap

| Phase | Content | Status |
|---|---|---|
| 1 | Data pipeline: FIT files -> per-second records -> daily load | done (20 Oct 2026) |
| 2 | Performance index (aerobic efficiency), weather and place covariates | done (21 Oct 2026) |
| 3 | System identification (variable projection), validation: model NOT identifiable from HR-based measures | done (25 Oct 2026) |
| 4 | State estimation (Kalman filter): aerobic baseline + fatigue effect, fitness open loop | done (26 Oct 2026) |
| 5 | Taper planning: linear program, robust over uncertain fatigue parameters, weekly re-planning (MPC) | done (30 Oct 2026), re-plan weekly |
| 6 | Pre-registered race prediction vs actual result, report | done (22 Nov 2026): predicted 1:34:08 (commit 580331d), actual 1:34:12 |

## Data windows

| Window | Role |
|---|---|
| Nov 2025 - Feb 2026 | state initialisation (burn-in, unstructured running) |
| Mar 2026 - 16 Aug 2026 | identification (incl. intentional summer break 1-16 Aug) |
| 17 Aug 2026 - 19 Oct 2026 | identification / validation (structured plan, 10 km race 27 Sep, 40:59) |
| 20 Oct 2026 - 22 Nov 2026 | online use, half marathon = final test |

## Repository structure

```
config.m                 athlete and pipeline parameters
startup_project.m        adds src/ to the path
main_01_pipeline.m       phase 1 entry point
main_02_performance.m    phase 2 entry point
main_03_identification.m phase 3 entry point
main_04_kalman.m         phase 4 entry point
main_05_taper.m          phase 5 entry point (run weekly until the race)
main_06_prediction.m     phase 6: pre-registered race prediction
main_07_race.m           phase 6: race analysis and registered checks
src/io/                  FIT header screening, conversion and parsing
src/load/                training-load metrics (TRIMP)
src/perf/                aerobic-efficiency index, grade adjustment (Minetti)
src/env/                 place labels, historical weather (Open-Meteo / ERA5)
src/model/               Banister states, variable-projection fit
src/estimation/          Kalman filter
src/control/             taper planning (linear programs, MPC)
data/raw/fit/            original FIT files        (NOT committed)
data/interim/csv/        FIT -> CSV conversions    (NOT committed)
data/processed/          daily datasets (.mat)     (NOT committed)
explore/                 exploratory scripts (synthetic Banister model)
notes/                   results log, literature notes
results/                 figures, tables
```

Raw data is never committed: activity files contain GPS tracks (home location).

## Data so far

114 runs (Nov 2025 - Oct 2026) from the full Garmin account export (20,413 FIT files,
screened by header: only activity files are converted). Three intentional rest periods
(late Dec, late Feb / early Mar, 1-16 Aug) provide natural zero-load segments.
Performance measure: aerobic efficiency (grade-adjusted speed per net heartbeat)
on 57 easy steady runs, measurement noise 2.9 % per run. No detectable day-to-day
temperature effect; no altitude/terrain penalty for L'Aquila runs.
Identification (Step 3): the fitness-fatigue model is not identifiable from these
HR-based measures; with fixed time constants the fatigue state RAISES the HR-based
efficiency (lower HR at a given speed after heavy training). Steps 4-5 use literature
time constants; the race prediction is anchored on the 10 km race.
See `notes/results_log.md`.

## Requirements

- MATLAB R2021a or newer
- Java (MATLAB ships its own, a system `java` on the PATH is also fine)
- `FitCSVTool.jar` from [garmin/fit-sdk-tools releases](https://github.com/garmin/fit-sdk-tools/releases), placed in `tools/`
