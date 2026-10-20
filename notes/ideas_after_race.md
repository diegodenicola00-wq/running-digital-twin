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

## Before the race, instead

- Kalman measurement noise R estimated from the data (maximum likelihood on the
  filter innovations), which includes all noise sources, not only the sensor.
