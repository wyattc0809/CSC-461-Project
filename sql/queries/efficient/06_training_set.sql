/* EFFICIENT 06 - final training set returned to Python
   Fixes:
     - explicit ANSI JOINs on clustered-index keys (merge joins, no sort needed)
     - native UNIQUEIDENTIFIER join to the patients PK
     - age computed inline (the same arithmetic as dbo.fn_age_years, with no UDF call)
     - no DISTINCT: (patient_id, snapshot_date) is already unique
   The output columns, types and order must match inefficient/06 exactly.
*/
USE SyntheaHealth;

SELECT
    s.patient_id,
    s.snapshot_date,
    DATEDIFF(YEAR, p.BIRTHDATE, s.snapshot_date)
      - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, p.BIRTHDATE, s.snapshot_date), p.BIRTHDATE)
                  > s.snapshot_date THEN 1 ELSE 0 END  AS age_years,
    p.GENDER                                           AS gender,
    p.INCOME                                           AS income,
    u.prior_admits_365,
    u.prior_ed_90,
    u.prior_visits_365,
    u.days_since_last_admit,
    c.active_conditions,
    c.active_meds,
    CAST(c.latest_bmi AS DECIMAL(5,1))                 AS latest_bmi,
    DATEPART(MONTH, s.snapshot_date)                   AS month_of_year,
    l.label
FROM fast.snapshots   s
JOIN clin.patients    p ON p.Id = s.patient_id
JOIN fast.utilization u ON u.patient_id = s.patient_id AND u.snapshot_date = s.snapshot_date
JOIN fast.clinical    c ON c.patient_id = s.patient_id AND c.snapshot_date = s.snapshot_date
JOIN fast.labels      l ON l.patient_id = s.patient_id AND l.snapshot_date = s.snapshot_date
ORDER BY s.patient_id, s.snapshot_date;
