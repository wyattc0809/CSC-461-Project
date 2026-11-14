/* EFFICIENT 04 - clinical state at each snapshot
   Fixes:
     - conditions and medications are aggregated in separate CTEs and joined back
       one-to-one (no row fan-out, no COUNT(DISTINCT) workaround)
     - (STOP IS NULL OR STOP > x) instead of ISNULL(STOP, ...) keeps the column bare
     - CAST(START AS DATE) <= d rewritten as START < d + 1 day (same meaning, SARGable)
     - OUTER APPLY TOP 1 seeks the (CODE, PATIENT, DATE DESC) index: about 3 page reads
       per snapshot instead of a full scan
     - VALUE_NUM was parsed once at load time (02_clin_tables.sql)
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS fast.clinical;

WITH cond AS (
    SELECT s.patient_id, s.snapshot_date, COUNT(c.PATIENT) AS active_conditions
    FROM fast.snapshots s
    LEFT JOIN clin.conditions c
           ON c.PATIENT = s.patient_id
          AND c.START  <= s.snapshot_date
          AND (c.STOP IS NULL OR c.STOP > s.snapshot_date)
    GROUP BY s.patient_id, s.snapshot_date
),
meds AS (
    SELECT s.patient_id, s.snapshot_date, COUNT(m.PATIENT) AS active_meds
    FROM fast.snapshots s
    LEFT JOIN clin.medications m
           ON m.PATIENT = s.patient_id
          AND m.START  <  DATEADD(DAY, 1, s.snapshot_date)
          AND (m.STOP IS NULL OR m.STOP >= DATEADD(DAY, 1, s.snapshot_date))
    GROUP BY s.patient_id, s.snapshot_date
)
SELECT s.patient_id, s.snapshot_date, cond.active_conditions, meds.active_meds, bmi.latest_bmi
INTO fast.clinical
FROM fast.snapshots s
JOIN cond ON cond.patient_id = s.patient_id AND cond.snapshot_date = s.snapshot_date
JOIN meds ON meds.patient_id = s.patient_id AND meds.snapshot_date = s.snapshot_date
OUTER APPLY (
    SELECT TOP 1 o.VALUE_NUM AS latest_bmi
    FROM clin.observations o
    WHERE o.CODE = '39156-5'                                  -- LOINC: Body mass index
      AND o.PATIENT = s.patient_id
      AND o.DATE < s.snapshot_date
    ORDER BY o.DATE DESC, o.VALUE_NUM DESC
) bmi;

CREATE CLUSTERED INDEX cx ON fast.clinical (patient_id, snapshot_date);
