/* EFFICIENT 05 - target label: was the patient admitted in the 30 days after the snapshot?
   Fixes:
     - one pass; the label is computed inline
     - EXISTS stops at the first matching admission
     - date arithmetic on the snapshot side, so (patient_id, admit_ts) can be range-seeked
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS fast.labels;

SELECT
    s.patient_id,
    s.snapshot_date,
    CASE WHEN EXISTS (
             SELECT 1
             FROM fast.admissions a
             WHERE a.patient_id = s.patient_id
               AND a.admit_ts  >= s.snapshot_date
               AND a.admit_ts  <  DATEADD(DAY, 30, s.snapshot_date)
         ) THEN 1 ELSE 0 END AS label
INTO fast.labels
FROM fast.snapshots s;

CREATE CLUSTERED INDEX cx ON fast.labels (patient_id, snapshot_date);
