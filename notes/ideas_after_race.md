# Ideas for after the half marathon (22 Nov 2026)

Extensions that are useful but not needed before the race.

## Sensor validation experiment (chest strap)

- Buy a chest strap (Polar H10 or Garmin HRM-Dual) AFTER the race: no new gear before it.
- Setup: Instinct 2 Solar stays on the wrist (optical HR, as in all project data);
  strap paired to the old Vivoactive 4S, worn on the other wrist → same run, two sensors.
- 6-8 runs: easy, intervals, tempo (wait for quality sessions to restart after recovery).
- Outputs:
  - optical vs strap TRIMP error: constant bias or growing with intensity?
  - optical HR lag at the start of intervals [s]
  - sensor contribution to the measurement noise (a LOWER BOUND of R: R also
    includes weather, terrain, sleep, ...)
- Report section: "measurement error characterisation" / sensitivity analysis:
  how much do the identified parameters change with strap-based TRIMP?

## Before the race, instead (done in Step 4, 26 Oct 2026)

- Kalman noise levels from the data: R from pairs of close runs (all noise sources,
  not only the sensor), process noise and fatigue coefficient by maximum likelihood
  on the innovations. The strap experiment gives the SENSOR share of R.

## Performance index for hilly runs and intervals (dynamic HR model)

- Problem (Step 2): HR lags behind changes of effort, so hilly runs and intervals look
  "unsteady" and are excluded (only 12 of 39 L'Aquila runs used).
- Idea: identify, run by run, a first-order dynamic model from grade-adjusted speed to HR:
  HR(t) = HR0 + G · [1/(T s + 1)] · GAP(t)   (gain G, time constant T, per run)
  The gain G (bpm per m/s) is the steady-state cost; EF ≈ 1/G uses EVERY run, not only
  the steady ones. T itself may change with fitness (faster HR kinetics when fitter).
- Nice link to the course material: per-run system identification (ARX / OE models).
- Status (Step 3, 25 Oct 2026): a POOLED version is done (shared G = 21.9 bpm per m/s,
  T = 80 s, drift 12.8 bpm/h; only the offset per run). The per-run model is NOT
  identifiable on easy runs: speed barely changes (no excitation). → see "Experiment
  design" below.

---

# Mechatronic extensions (list of 26 Oct 2026)

Ordered from the most "mechatronic" to the least. Recommended pair: **A + B**
(identify the HR plant with a designed test, then control it): it closes the loop
identification → control → embedded → field test on a real system.

## A. HR-based pace controller (closed loop on the runner)

- Plant already identified (Step 3, pooled): GAP speed → HR, first order,
  G ≈ 21.9 bpm per m/s, T ≈ 80 s, plus the lag of the optical sensor (to measure, see C).
- Design a PI controller that tells the runner to speed up / slow down to hold a
  target HR: root locus / loop shaping, anti-windup (speed limits), effect of the
  sensor delay on stability margins. The "actuator" is the runner (human in the loop):
  model the reaction time and the quantised commands (faster / slower).
- Simulate in MATLAB/Simulink on the identified model, then on recorded runs.
- Embedded: Garmin Connect IQ data field (Monkey C) on the Instinct 2 Solar,
  showing the command in real time. Field test on easy runs: HR error vs target,
  compared with running "by feel".

## B. Experiment design for HR dynamics (persistent excitation)

- Designed test run on a flat track: speed steps, e.g. 4 min at 10 km/h / 4 min at
  13 km/h, repeated 3-4 times (or a pseudo-random sequence of the two levels).
- Identify G and T per SESSION (output-error / ARX), with confidence intervals.
- Repeat every 2-3 weeks: does T get shorter with fitness (faster HR kinetics)?
  Does G change? A per-session measure of fitness that is not the EF.
- Course link: input design, persistent excitation, identifiability.

## C. Additional sensor to improve observability (chest strap + HRV)

- With the chest strap (see above), record beat-to-beat RR intervals.
- Morning HRV (rMSSD, 3-5 min supine, same conditions every day) as a SECOND
  measurement in the Kalman filter: it responds to fatigue differently from the EF.
- Question: does the observability matrix go from rank 2 to rank 3? Does fitness
  become observable? Compare the filter with and without the HRV measurement.
- Same sessions give the optical-sensor validation (bias, lag, share of R).

## D. Sensor fusion for running speed

- GPS speed is noisy (trees, hills in L'Aquila) and enters GAP, EF and TRIMP-based
  comparisons.
- Kalman / complementary filter fusing GPS speed, cadence (wrist accelerometer) and
  barometric altitude → cleaner speed and grade.
- Hardware variant: home-made foot pod (ESP32 + IMU, ~30 EUR): stride-by-stride
  speed, stride length, ground contact time; validate against the track (400 m laps).

## E. Nonlinear estimation

- Extended / unscented Kalman filter on Busso's (2003) variable dose-response model
  (fatigue gain that grows with recent load).
- Joint state-parameter estimation (parameters as extra states with small process
  noise): do the estimated gains drift during the season?

## F. Small improvements of the current filter

- Local linear trend on the baseline b (one more state): removes the validation bias
  of Step 4 (mean normalized innovation +0.32, 17/25 positive).
- Air temperature as a measured input of the filter instead of a covariate.

