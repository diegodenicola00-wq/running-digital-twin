# Results log

Running notes on intermediate results. Newest entries at the bottom.
Each entry: date, what was run, what came out, what it means.

---

## 2026-10-19 — Pipeline test on 4 activities

**Run:** `main_01_pipeline` on 4 manually exported FIT files
(Garmin Connect → Export Original). Full account export still pending.

### Pipeline validation

Duration, distance and average HR computed from the 1 Hz records match the
Garmin Connect activity summaries (e.g. race: 40:58, 10.01 km, 188 bpm;
long run: 90:40, 17.01 km, 151 bpm). No activity flagged for optical-HR
dropouts (all >90% usable HR).

### Training load: Banister TRIMP vs Garmin Training Load

| Date | Session | Duration [min] | Avg HR [bpm] | TRIMP | Garmin load | Garmin / TRIMP |
|---|---|---|---|---|---|---|
| 2026-10-13 | Easy run 9 km | 53.4 | 145 | 77.8 | 79.8 | 1.0 |
| 2026-10-18 | Long run 17 km | 90.7 | 151 | 152.7 | 152.9 | 1.0 |
| 2026-10-15 | 4×1 km intervals | 53.0 | 149 | 88.2 | 168.5 | 1.9 |
| 2026-09-27 | 10 km race (Polimi Run) | 41.0 | 188 | 142.0 | 374.8 | 2.6 |

TRIMP: Banister (1991), integrated second by second, HRrest = 45, HRmax = 200, male coefficients.
Garmin load: `activityTrainingLoad` from Garmin Connect (EPOC-based, Firstbeat).

**Observations**

- Below threshold the two metrics agree almost exactly (partly a scale coincidence).
- Above threshold they diverge, and the ratio grows with intensity:
  Garmin weighs high-intensity work much more steeply than TRIMP's exponential.
- Intervals vs long run: almost the same average HR (149 vs 151), but Garmin gives
  the intervals ~2× more load per minute, because it sees the zone-4 peaks.
  Average HR hides the session structure.

**Implication for the model**

The choice of input w[k] is a modelling hypothesis, not a given. With TRIMP the
race weighs like a long run; with Garmin load it weighs ~2.5 long runs.
→ Phase 3: identify the Banister model with both inputs and compare
  predictive performance (controlled comparison).

**Caveat:** 4 sessions only. Repeat on the full dataset (scatter plot TRIMP vs
Garmin load, coloured by intensity) when the Garmin export arrives.

---

## 2026-10-20 — Full Garmin export, Step 1 on complete data

**Run:** `main_01_pipeline` on the full account export (20,413 FIT files).
Header screening (`fit_file_info.m`): 569 activity files in total, 108 from
01-Mar-2026; 90 runs between 2026-03-08 and 2026-10-18.

**Data issues found and fixed**
- 4 activities counted twice (manual "Export Original" + account export, different
  file names, identical content) → deduplication by start time; manual copies removed.
- Activity CSVs of ~3 KB (no records, e.g. manual entries) are discarded (<60 samples).

**August 2026: intentional training break (athlete's note)**
- 1–16 Aug: holiday, running stopped on purpose (yearly ~2-week summer break).
  One unstructured "for fun" run in that window.
- These are TRUE zeros of the input w[k], not missing data.
- Modelling value: a natural step-down experiment. With no load, fitness and
  fatigue decay freely → direct information on tau1 / tau2 (detraining),
  rarely observable during normal training.

**Data window extended backwards**
- Running before March 2026 was unstructured but is still training load.
- `cfg.dates.dataStart` moved to 2025-11-01 (burn-in of the states);
  `cfg.dates.idStart` = 2026-03-01 (earliest date usable for identification).

**Re-run after dedup + burn-in from Nov 2025 (same day)**
- 565 activity files in total (569 − 4 manual duplicates), 167 from 2025-11-01;
  **114 runs** between 2025-11-01 and 2026-10-18. Duplicates gone (race day back to TRIMP ≈ 142).
- Figure `results/fig01_daily_load.png`, fixed-parameter proxies (tau = 42 d / 7 d):
  - fitness proxy: ~0 (Nov 2025, burn-in) → ~15 (Mar) → peak ~39 (mid-July)
    → drop during the August break (~24) → ~36 now;
  - three natural "load-off" periods visible: late Dec 2025, late Feb / early Mar 2026,
    1–16 Aug 2026. Each one is a free-decay segment useful for identifying tau1, tau2.
- Cause of the breaks (athlete's note, 2026-10-20): all three (late Dec, late Feb/early Mar,
  August) were INTENTIONAL rest periods, no illness or injury. They are clean zero-input
  segments: performance changes there can be attributed to the load alone.
- These curves use literature time constants; NOT the identified model (Step 3).

**Step 1 closed.**

---

## 2026-10-20 — Devices and sensor consistency

- Garmin Vivoactive 4S until 2025-11-02; Garmin Instinct 2 Solar from 2025-11-03.
  Never used a chest strap: HR is always wrist optical.
- Consequence: the whole dataset from 2025-11-03 comes from ONE device →
  no artificial jumps from a sensor change in HR, pace, cadence or power.
  Only the run(s) on 1–2 Nov 2025 (burn-in window) come from the old watch: negligible.
  If the data window is ever extended before Nov 2025, the device change must be handled.
- Wrist optical HR caveats: lag at the start of hard efforts, possible cadence lock,
  less reliable in short intervals. Steady easy runs are where it is most reliable
  → design choice for Step 2: build the performance index from steady easy runs.
- Stored in `config.m` as `cfg.device.change`.

---

## 2026-10-21 — Step 2, first run: aerobic efficiency index (EF)

**Method:** EF = grade-adjusted speed [m/min] / (HR − HRrest) → metres per net beat.
GAP via Minetti et al. (2002); window 10–45 min; 30 s smoothing; selection: CV ≤ 0.10,
steady share ≥ 0.80, HR reserve ≤ 0.75. Thresholds chosen on a 19-run Python prototype.

**Numbers:** 114 runs → 108 with a valid window → **57 selected** (easy + steady).
Excluded: 6 too short, 44 unsteady, 7 too intense.
Noise estimate from 22 pairs ≤ 3 days apart: **σ = 0.062 m/beat (3.9 % of mean EF)**.

**What the EF series shows (5-run running median)**
- Nov 2025 ~1.50 → Dec ~1.62 → Jan–Feb ~1.49 → Mar ~1.54 → May peak ~1.66
  → June–July DOWN to ~1.55 → Sep peak ~1.71 → Oct ~1.62.
- Range of the median ≈ ±7 % around the mean; noise ≈ 4 % per run → modest SNR.

**Interpretation (open)**
1. *Summer dip*: in June–July EF falls while the fitness proxy keeps rising (peak ~40).
   Two candidate causes, both seasonal and therefore confounded:
   - heat: higher HR at the same speed (thermoregulation, cardiovascular drift);
   - accumulated fatigue: the fatigue proxy is at its maximum in July.
2. *September peak right after the August break*: NOT necessarily in contradiction with
   the model. Banister predicts p = k1·x1 − k2·x2: after a rest the fatigue is gone while
   part of the fitness remains → performance can rise (taper / supercompensation).
   EF must be compared with k1·x1 − k2·x2, not with fitness alone → Step 3.
3. The watch records no temperature in the FIT records (checked: no `temperature`
   field) → a temperature correction needs external weather data.

**Next candidate actions**
- Temperature covariate from historical weather (Milan, hourly) → EF corrected for heat.
- Threshold sensitivity (e.g. maxCV 0.10 vs 0.12): many urban easy runs may be
  "unsteady" only because of traffic-light stops.
- External sanity check: Garmin VO2max estimates from the export
  (DI-Connect-Fitness, summarizedActivities JSON).

---

## 2026-10-21 — Step 2: place and weather (Open-Meteo / ERA5)

**Athlete's note:** runs from 3 Jul to 12 Sep 2026 (and other periods of the year) in
L'Aquila: ~600–720 m a.s.l., hilly. Summer heat perceived as hard.

**Data:** start GPS position of every run → place: Milano 72, L'Aquila 39, other 1
(southern Greece), no GPS 2 (treadmill). Hourly temperature, humidity and apparent
temperature at the place and mid-time of every run (Open-Meteo archive, ERA5).

**Results (first run)**
- Heat effect (EF residual vs 9-run running median, regressed on air temperature):
  **−0.0000 m/beat per °C, SE 0.0010, n = 55** → no detectable day-to-day effect.
  A plausible physiological effect (~0.004–0.008 m/beat per °C, i.e. a few bpm more
  between cool and hot days) would be 4–8 SE away: the data do NOT support it at the
  day-to-day scale. Same result with apparent temperature.
- Place after the temperature term: L'Aquila +0.021 (n = 10), Milano −0.005 (n = 45)
  m/beat → no penalty for altitude/terrain (GAP correction works); not significant
  (SE ≈ 0.02).
- Only 10 of 39 L'Aquila runs pass the selection (hills raise the CV).

**Two problems found in the first version, fixed**
- The 2 treadmill runs (no GPS: speed from the wrist accelerometer) were in the
  selection: very likely the two low outliers in Jan–Feb (EF ≈ 1.36). Now excluded.
- Raw vs corrected noise were computed on DIFFERENT pairs (NaN weather removed some):
  σ 0.062 → 0.046 was an artefact, not an effect of the correction. Now same pairs.

**Interpretation**
- Day-to-day temperature does not explain the June–July EF dip. Remaining candidates:
  accumulated fatigue (what Banister's k2·x2 term models) or a slow seasonal effect
  (heat acclimatisation) that the running-median method cannot separate from fitness.
- Method limitation: the running median absorbs slow seasonal effects; points at the
  centre of the window get residual exactly 0. The rigorous test is in Step 3:
  estimate Banister parameters and a temperature coefficient JOINTLY.

**Added:** treadmill exclusion; sensitivity of the selection to maxCV (0.08–0.15).

**Re-run with treadmill runs excluded (same day)**
- 55 runs selected (2 treadmill runs removed).
- Noise on the same 21 pairs ≤ 3 days: **σ = 0.046 m/beat (2.9 % of mean EF)**, raw and
  temperature-corrected identical (slope ≈ 0). The earlier 3.9 % was inflated by the
  two treadmill runs.
- Signal (range of the running median ≈ ±7 %) vs noise 2.9 % per run → usable for Step 3.
- maxCV sensitivity: 0.10 / 0.12 / 0.15 → 55 / 55 / 56 runs (flat region → robust);
  0.08 → 42. The CV threshold is NOT the binding constraint: the "unsteady" exclusions
  come from the steady-share criterion (minSteady = 0.80).
- Open: summer (Jul–Sep, L'Aquila) is poorly covered (10 of 39 L'Aquila runs selected),
  and that is exactly where the August break response lives → check minSteady
  sensitivity (0.6 / 0.7 / 0.8) and why L'Aquila runs are excluded.

**Steady-share sensitivity and final choice (same day)**

| minSteady | selected | L'Aquila | Jul–Sep | σ (21 pairs ≤ 3 d) |
|---|---|---|---|---|
| 0.60 | 57 | 12 | 10 | 0.046 |
| 0.70 | 57 | 12 | 10 | 0.046 |
| 0.80 | 55 | 10 | 9 | 0.046 |

- L'Aquila runs excluded (26, criteria overlap): CV > max 22, steady share < min 24,
  too intense 10. Hilly runs fail several criteria at once: on climbs HR rises above the
  easy cap and GAP fluctuates. Relaxing one threshold recovers only 2 runs.
- Root cause: HR responds to a change of effort with a lag (~tens of seconds), GAP changes
  instantly → on rolling terrain a "steady effort" looks unsteady sample by sample.
  → idea for later: per-run dynamic model HR(t) = HR0 + G·[first-order lag]·GAP(t),
  EF ≈ 1/G (see notes/ideas_after_race.md).
- **Choice: minSteady = 0.70** (middle of the flat region, same noise, +2 runs).

**Step 2 closed.** Output for Step 3: `data/processed/performance.mat`, table P
(57 easy steady runs: day, EF, temperature, place, altitude), σ = 0.046 m/beat (2.9 %).
Temperature kept as a covariate to be re-tested jointly with the Banister model.

---

## 2026-10-25 — Step 3, session 1: first identification (Python prototype)

**Data:** daily TRIMP from 2025-11-01 (burn-in), EF of the 57 selected runs;
identification on the 43 measurements from 2026-03-01.
**Method:** variable projection — grid over tau1 (5–150 d) and tau2 (1–40 d), for each
pair the gains (p0, k1, k2) by linear least squares; global minimum of the RSS.

**Results: the fitness–fatigue model does NOT explain the EF series**
- Best fit at the edges of the grid (tau1 = 150 d, tau2 = 2.5 d), k2 < 0 (unphysical);
  RMSE 0.057 vs 0.060 of a constant model; R2 = 0.09.
- 95 % confidence region covers the whole grid (tau1 5–150, tau2 1–40): parameters
  not identifiable at all.
- AIC: constant model (−240.4) ≥ fitness-only (−239.4) > full Banister (−236.3).
- With non-negative gains: R2 = 0.08 (Mar+), 0.26 using all data from Nov (only a slow
  trend, tau at the upper bound).
- Literature time constants (42 / 7 d), gains fitted: R2 = 0.06 (Mar+), fitness and
  fatigue terms not significant (t = 0.1 and −0.8).
- Validation (fit Mar–16 Aug, predict 17 Aug–18 Oct, 14 points): RMSE 0.067 vs 0.067
  of the training mean → no predictive skill.

**Why (diagnosis)**
- Signal-to-noise: from March the EF varies with std 0.060; measurement noise 0.046
  → true signal std ≈ 0.038 (≈ 2.4 %), i.e. SNR ≈ 1 per run, with 43 runs and
  5 parameters.
- The variation that exists is mostly SEASONAL: monthly mean EF is low in winter
  (Jan 1.42, Feb 1.52, ~8–10 °C), high in spring/autumn (1.62–1.67), lower in June (1.58, 29 °C).
  EF vs raw temperature: quadratic, R2 = 0.34 (all data), vertex ≈ 23 °C;
  t-stats ≈ 4–5. But the day-to-day analysis (Step 2) found NO temperature effect →
  the seasonal correlation is confounded with season / fitness, not a proven causal effect.
- EF (submaximal efficiency) may simply be weakly sensitive to short-term fatigue,
  which in Banister's original work is measured on maximal performance.

**Status:** open decision on how to proceed (better output measure, fixed time
constants with priors, or different performance metric). See next entry.

---

## 2026-10-25 — Step 3, session 1b: dynamic HR index on ALL runs (Python prototype)

**Idea:** instead of selecting steady runs, model HR as the first-order response to
grade-adjusted speed: HR(t) = c_run + G·[1/(T s+1)]·v_GAP(t) + d·t.
G, T, d shared by all runs (same physiology), offset c_run per run → HR predicted at
3.0 m/s (10.8 km/h) at minute 20 → "dynamic EF" = 180 / (HR_ref − HRrest).

**Data:** per-second export of all runs (`data/processed/runs_1hz.csv`), 114 runs;
excluded 2 treadmill runs and 2 near-maximal runs (mean HR ≥ 175: races).

**Pooled HR model (109 runs):** T = 80 s, G = 21.9 bpm per m/s (≈ 6 bpm per km/h),
drift 12.8 bpm/h, RMSE 7.3 bpm (easy runs 3–5 bpm, intervals 9–16 bpm).
A free model per run is NOT identifiable on easy runs (narrow speed range → G, T at bounds).

**Dynamic EF:** 109 runs (vs 57), summer covered (Jul 11 runs, Aug 7, Sep 11).
Noise from 89 pairs ≤ 3 days: σ = 0.077 (4.7 %) vs 2.9 % of the steady-run EF;
total std 0.087 → signal std ≈ 0.040 (similar to the steady EF).

**Banister identification on the dynamic EF:** again NOT identifiable.
- Mar+ (81 days): R2 = 0.11, best tau1 = 18, tau2 = 17.5, both gains NEGATIVE;
  95 % region = whole grid. AIC full −399.1 vs constant −397.9 (no real gain).
- Validation (fit Mar–16 Aug, predict 17 Aug–18 Oct): RMSE 0.104 vs 0.087 of the
  training mean → WORSE than a constant.

**Key finding: the fatigue term has the WRONG sign, consistently**
With literature time constants fixed, t-statistics of the two states:

| series | tau | window | t(fitness) | t(fatigue state; + = raises EF) |
|---|---|---|---|---|
| steady EF (57) | 42/7 | all / Mar+ | +2.1 / +0.1 | +0.4 / +0.8 |
| dynamic EF (107 days) | 42/7 | all / Mar+ | +0.1 / −0.6 | **+2.8 / +2.2** |
| dynamic EF | 42/3 , 60/10 | all | +1.1 , +0.1 | **+2.6 , +2.7** |

Recent training load RAISES the HR-based efficiency: after heavy training, HR at a
given speed is LOWER. This is consistent with the literature on over-reaching:
Bosquet et al. (2008, BJSM 42(9)) — submaximal HR decreases slightly with
over-reaching (1–6 bpm with > 2 weeks of overload), within day-to-day variability.
→ An HR-based submaximal index confounds fatigue with fitness: both lower the HR
at a given speed. It cannot serve as the output p[k] of Banister's model, whose
fatigue term assumes that fatigue LOWERS performance (measured on maximal efforts).

**Conclusion of Step 3 so far:** with HR-based performance measures from training,
the fitness–fatigue model is not identifiable on these data, and the reason is
structural (measurement confound), not only noise. Decision on how to continue: next entry.

---

## 2026-10-25 — Decision: Plan B + race anchor

Athlete's choice: Plan B + race. Only one race in the period (10 km, 27 Sep 2026, 40:59).

**What changes**
- Time constants fixed from the literature (tau1 = 42 d, tau2 = 7 d); the non-identifiability
  is a RESULT of the report (Section 6), with its diagnosis (SNR + fatigue/HR confound).
- State estimation (Step 4): Banister dynamics with literature tau as the process model;
  the dynamic EF can still be used as a measurement, with an EMPIRICAL measurement
  equation (fatigue raises EF, as found above), identified with tau fixed.
- Planning (Step 5): MPC on the literature model (form = fitness − fatigue).
- Race prediction: anchored on the 10 km race. Riegel equivalent (T2 = T1·(d2/d1)^e):
  e = 1.04 / 1.06 / 1.08 → 1:29:05 / 1:30:25 / 1:31:47 (4:13 / 4:17 / 4:21 per km).
  The model only contributes the RELATIVE change of form between 27 Sep and 22 Nov,
  bounded by the taper effect reported in the literature (Mujika & Padilla 2003).

**Limits to state clearly:** one race = one anchor → the absolute gains k1, k2 cannot be
estimated; the prediction is a calibrated extrapolation, not an identified model.
