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
