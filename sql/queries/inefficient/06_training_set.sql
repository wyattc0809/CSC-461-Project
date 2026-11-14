/* INEFFICIENT 06 - final training set returned to Python
   Anti-patterns:
     - old-style comma joins, with join conditions mixed into WHERE
     - CONVERT(NVARCHAR(36), p.Id) = s.patient_id: the patients PK can't be seeked
     - dbo.fn_age_years(): a scalar UDF called per row (not inlined below compat level 150)
     - DISTINCT on rows that are already unique: an extra sort/hash for nothing
     - ORDER BY ordinal position (1, 2): fragile
   The output columns, types and order must match efficient/06 exactly.
*/
USE SyntheaHealth;

SELECT DISTINCT
    CONVERT(UNIQUEIDENTIFIER, s.patient_id)          AS patient_id,
    s.snapshot_date,
    dbo.fn_age_years(p.BIRTHDATE, s.snapshot_date)   AS age_years,
    p.GENDER                                         AS gender,
    p.INCOME                                         AS income,
    u.prior_admits_365,
    u.prior_ed_90,
    u.prior_visits_365,
    u.days_since_last_admit,
    c.active_conditions,
    c.active_meds,
    CAST(c.latest_bmi AS DECIMAL(5,1))               AS latest_bmi,
    DATEPART(MONTH, s.snapshot_date)                 AS month_of_year,
    l.label
FROM slow.snapshots s, clin.patients p, slow.utilization u, slow.clinical c, slow.labels l
WHERE CONVERT(NVARCHAR(36), p.Id) = s.patient_id
  AND u.patient_id = s.patient_id AND u.snapshot_date = s.snapshot_date
  AND c.patient_id = s.patient_id AND c.snapshot_date = s.snapshot_date
  AND l.patient_id = s.patient_id AND l.snapshot_date = s.snapshot_date
ORDER BY 1, 2;
