/* =============================================================================
   03_indexes.sql
   These indexes exist for BOTH variants. The inefficient queries are written in
   ways that keep the optimizer from using them (functions on columns, implicit
   conversions, row-by-row loops). The efficient queries are written so it can.
   ========================================================================== */
USE SyntheaHealth;
GO

-- Most feature lookups are "this patient's encounters in a date window".
CREATE CLUSTERED INDEX cx_encounters_patient_start
    ON clin.encounters (PATIENT, START);

-- Filtered index: admissions only (inpatient + emergency, about 5% of encounters).
CREATE NONCLUSTERED INDEX ix_encounters_admissions
    ON clin.encounters (PATIENT, START)
    INCLUDE (ENCOUNTERCLASS, STOP)
    WHERE ENCOUNTERCLASS IN ('inpatient', 'emergency');

CREATE CLUSTERED INDEX cx_conditions_patient ON clin.conditions  (PATIENT, START);
CREATE CLUSTERED INDEX cx_medications_patient ON clin.medications (PATIENT, START);

-- observations is the biggest table (~957K rows). Seek by code, then patient, then latest date.
CREATE CLUSTERED INDEX cx_observations_code_patient_date
    ON clin.observations (CODE, PATIENT, DATE DESC);
GO

UPDATE STATISTICS clin.encounters  WITH FULLSCAN;
UPDATE STATISTICS clin.observations WITH FULLSCAN;
GO
