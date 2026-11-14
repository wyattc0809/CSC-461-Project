/* EFFICIENT 01 - admission events (inpatient + emergency) since 2016
   Fixes:
     - only the columns used downstream
     - a plain date range on START, so the index can be seeked (SARGable)
     - IN (...) matches the filtered index ix_encounters_admissions exactly
     - clustered index on the output, in the order later steps read it
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS fast.admissions;

SELECT PATIENT AS patient_id, START AS admit_ts, ENCOUNTERCLASS AS encounter_class
INTO fast.admissions
FROM clin.encounters
WHERE START >= '2016-01-01'
  AND ENCOUNTERCLASS IN ('inpatient', 'emergency');

CREATE CLUSTERED INDEX cx ON fast.admissions (patient_id, admit_ts);
