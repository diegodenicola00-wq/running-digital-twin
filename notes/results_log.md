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
