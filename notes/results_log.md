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
