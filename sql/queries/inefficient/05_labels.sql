/* INEFFICIENT 05 - target label: was the patient admitted in the 30 days after the snapshot?
   Anti-patterns:
     - two passes: write every row with label = 0, then UPDATE the positives
     - COUNT(*) > 0 counts every match when one is enough (use EXISTS)
     - DATEADD(DAY, -30, a.START): date arithmetic on the column, not the parameter
     - reads slow.admissions, a heap with no index, through CONVERT(NVARCHAR(36), ...)
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS slow.labels;

SELECT patient_id, snapshot_date, 0 AS label
INTO slow.labels
FROM slow.snapshots;

UPDATE l
SET label = 1
FROM slow.labels l
WHERE (SELECT COUNT(*)
         FROM slow.admissions a
        WHERE CONVERT(NVARCHAR(36), a.PATIENT) = l.patient_id
          AND a.START >= l.snapshot_date
          AND DATEADD(DAY, -30, a.START) < l.snapshot_date) > 0;
