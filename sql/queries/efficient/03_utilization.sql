/* EFFICIENT 03 - prior utilization features per snapshot
   Fixes:
     - one range JOIN plus conditional aggregation: a single pass reads each
       patient's encounters once
     - native UNIQUEIDENTIFIER = UNIQUEIDENTIFIER join, so the clustered index
       (PATIENT, START) is seeked
     - a half-open date range [snapshot - 365d, snapshot) is SARGable and is
       logically identical to DATEDIFF(...) BETWEEN 1 AND 365
     - MAX() instead of TOP 1 ... ORDER BY
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS fast.utilization;

SELECT
    s.patient_id,
    s.snapshot_date,
    COUNT(CASE WHEN e.ENCOUNTERCLASS IN ('inpatient', 'emergency') THEN 1 END)        AS prior_admits_365,
    COUNT(CASE WHEN e.ENCOUNTERCLASS = 'emergency'
                AND e.START >= DATEADD(DAY, -90, s.snapshot_date) THEN 1 END)        AS prior_ed_90,
    COUNT(e.PATIENT)                                                                  AS prior_visits_365,
    DATEDIFF(DAY, MAX(CASE WHEN e.ENCOUNTERCLASS IN ('inpatient', 'emergency')
                           THEN e.START END), s.snapshot_date)                        AS days_since_last_admit
INTO fast.utilization
FROM fast.snapshots s
LEFT JOIN clin.encounters e
       ON e.PATIENT = s.patient_id
      AND e.START  >= DATEADD(DAY, -365, s.snapshot_date)
      AND e.START  <  s.snapshot_date
GROUP BY s.patient_id, s.snapshot_date;

CREATE CLUSTERED INDEX cx ON fast.utilization (patient_id, snapshot_date);
