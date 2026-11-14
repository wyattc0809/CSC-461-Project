/* INEFFICIENT 02 - one row per (living patient, month start), Jan 2017 - Sep 2026
   Anti-patterns:
     - a CURSOR over patients plus a nested WHILE loop over months: ~1,183 x 117
       single-row INSERTs, each its own statement and log write (row by row)
     - patient_id stored as NVARCHAR(36): every later join to the UNIQUEIDENTIFIER
       columns in clin.* needs an implicit conversion
*/
USE SyntheaHealth;
DROP TABLE IF EXISTS slow.snapshots;
CREATE TABLE slow.snapshots (patient_id NVARCHAR(36), snapshot_date DATE);

DECLARE @pid NVARCHAR(36), @birth DATE, @death DATE, @d DATE;

DECLARE patient_cursor CURSOR FOR
    SELECT CONVERT(NVARCHAR(36), Id), BIRTHDATE, DEATHDATE FROM clin.patients;

OPEN patient_cursor;
FETCH NEXT FROM patient_cursor INTO @pid, @birth, @death;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @d = '2017-01-01';
    WHILE @d <= '2026-09-01'
    BEGIN
        IF @birth <= @d AND (@death IS NULL OR @death > @d)
            INSERT INTO slow.snapshots (patient_id, snapshot_date) VALUES (@pid, @d);
        SET @d = DATEADD(MONTH, 1, @d);
    END;
    FETCH NEXT FROM patient_cursor INTO @pid, @birth, @death;
END;

CLOSE patient_cursor;
DEALLOCATE patient_cursor;
