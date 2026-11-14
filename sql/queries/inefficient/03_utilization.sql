/* INEFFICIENT 03 - prior utilization features per snapshot
   Anti-patterns:
     - four correlated subqueries: clin.encounters is probed 4x per snapshot row (~100K rows)
     - CONVERT(NVARCHAR(36), e.PATIENT) = ... : a function on the indexed column, so
       every probe scans the table instead of seeking
     - DATEDIFF(DAY, e.START, ...) BETWEEN: another non-SARGable date filter
     - TOP 1 ... ORDER BY inside a subquery when MAX() would do
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS slow.utilization;

SELECT
    s.patient_id,
    s.snapshot_date,
    (SELECT COUNT(*)
       FROM clin.encounters e
      WHERE CONVERT(NVARCHAR(36), e.PATIENT) = s.patient_id
        AND DATEDIFF(DAY, e.START, s.snapshot_date) BETWEEN 1 AND 365
        AND e.ENCOUNTERCLASS IN ('inpatient', 'emergency'))           AS prior_admits_365,
    (SELECT COUNT(*)
       FROM clin.encounters e
      WHERE CONVERT(NVARCHAR(36), e.PATIENT) = s.patient_id
        AND DATEDIFF(DAY, e.START, s.snapshot_date) BETWEEN 1 AND 90
        AND e.ENCOUNTERCLASS = 'emergency')                           AS prior_ed_90,
    (SELECT COUNT(*)
       FROM clin.encounters e
      WHERE CONVERT(NVARCHAR(36), e.PATIENT) = s.patient_id
        AND DATEDIFF(DAY, e.START, s.snapshot_date) BETWEEN 1 AND 365) AS prior_visits_365,
    (SELECT TOP 1 DATEDIFF(DAY, e.START, s.snapshot_date)
       FROM clin.encounters e
      WHERE CONVERT(NVARCHAR(36), e.PATIENT) = s.patient_id
        AND DATEDIFF(DAY, e.START, s.snapshot_date) BETWEEN 1 AND 365
        AND e.ENCOUNTERCLASS IN ('inpatient', 'emergency')
      ORDER BY e.START DESC)                                          AS days_since_last_admit
INTO slow.utilization
FROM slow.snapshots s;
