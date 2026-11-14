/* EFFICIENT 02 - one row per (living patient, month start), Jan 2017 - Sep 2026
   Fixes:
     - set-based: generate the 117 months once, then a single JOIN against patients
     - patient_id keeps its native UNIQUEIDENTIFIER type, so later joins need no conversion
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS fast.snapshots;

DECLARE @first DATE = '2017-01-01', @last DATE = '2026-09-01';

WITH months AS (
    SELECT TOP (DATEDIFF(MONTH, @first, @last) + 1)
           DATEADD(MONTH, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @first) AS snapshot_date
    FROM sys.all_objects
)
SELECT p.Id AS patient_id, m.snapshot_date
INTO fast.snapshots
FROM clin.patients p
JOIN months m
  ON p.BIRTHDATE <= m.snapshot_date
 AND (p.DEATHDATE IS NULL OR p.DEATHDATE > m.snapshot_date);

CREATE CLUSTERED INDEX cx ON fast.snapshots (patient_id, snapshot_date);
