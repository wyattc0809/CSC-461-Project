/* =============================================================================
   04_functions.sql
   An "old" scalar UDF, the kind real codebases are full of. The inefficient
   pipeline calls it once per row. On compatibility level < 150 it can't be
   inlined and also forces the whole query to run on a single thread.
   ========================================================================== */
USE SyntheaHealth;
GO

CREATE OR ALTER FUNCTION dbo.fn_age_years (@birth DATE, @as_of DATE)
RETURNS INT
AS
BEGIN
    DECLARE @age INT = DATEDIFF(YEAR, @birth, @as_of);
    IF DATEADD(YEAR, @age, @birth) > @as_of
        SET @age = @age - 1;
    RETURN @age;
END;
GO
