/* INEFFICIENT 01 - admission events (inpatient + emergency) since 2016
   Anti-patterns:
     - SELECT *: copies all 11 columns when 3 are used downstream
     - YEAR(START) >= 2016: a function on the column, so the index can't be seeked (non-SARGable)
     - LOWER(ENCOUNTERCLASS) ... OR ...: another function on a column, and it doesn't
       match the filtered index predicate
     - no index on the output table
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS slow.admissions;

SELECT *
INTO slow.admissions
FROM clin.encounters
WHERE YEAR(START) >= 2016
  AND (LOWER(ENCOUNTERCLASS) = 'inpatient' OR LOWER(ENCOUNTERCLASS) = 'emergency');
