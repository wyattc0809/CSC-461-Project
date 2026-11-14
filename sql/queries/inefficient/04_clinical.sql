/* INEFFICIENT 04 - clinical state at each snapshot
   Anti-patterns:
     - correlated subqueries again (3 probes per snapshot row)
     - ISNULL(STOP, '9999-12-31') > x and CAST(START AS DATE): functions on columns
     - RTRIM(o.CODE) = N'39156-5': a function plus an NVARCHAR literal against a VARCHAR
       column; scans all ~957K observation rows for every snapshot
     - TRY_CAST(VALUE ...) parses text on every row, every run, instead of once at load
       (careful: casting through FLOAT here would change rounding and break equivalence)
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS slow.clinical;

SELECT
    s.patient_id,
    s.snapshot_date,
    (SELECT COUNT(*)
       FROM clin.conditions c
      WHERE CONVERT(NVARCHAR(36), c.PATIENT) = s.patient_id
        AND c.START <= s.snapshot_date
        AND ISNULL(c.STOP, '9999-12-31') > s.snapshot_date)                  AS active_conditions,
    (SELECT COUNT(*)
       FROM clin.medications m
      WHERE CONVERT(NVARCHAR(36), m.PATIENT) = s.patient_id
        AND CAST(m.START AS DATE) <= s.snapshot_date
        AND ISNULL(CAST(m.STOP AS DATE), '9999-12-31') > s.snapshot_date)    AS active_meds,
    (SELECT TOP 1 TRY_CAST(o.VALUE AS DECIMAL(10,2))
       FROM clin.observations o
      WHERE CONVERT(NVARCHAR(36), o.PATIENT) = s.patient_id
        AND RTRIM(o.CODE) = N'39156-5'                       -- LOINC: Body mass index
        AND o.DATE < s.snapshot_date
      ORDER BY o.DATE DESC, TRY_CAST(o.VALUE AS DECIMAL(10,2)) DESC)        AS latest_bmi
INTO slow.clinical
FROM slow.snapshots s;
