/* =============================================================================
   00_create_db.sql
   Creates the database and the four schemas used by the project.

     stg   raw CSV landing tables (everything VARCHAR, no keys)
     clin  typed, keyed, indexed clinical tables (what the queries read)
     slow  output tables written by sql/queries/inefficient/*
     fast  output tables written by sql/queries/efficient/*
   ========================================================================== */
IF DB_ID('SyntheaHealth') IS NULL
    CREATE DATABASE SyntheaHealth;
GO

USE SyntheaHealth;
GO

-- Compatibility level = the optimizer "version" (Track 2 knob).
-- 160 = SQL Server 2022 (scalar UDF inlining, new cardinality estimator).
-- The benchmark can drop this to 140 to show what the old optimizer does.
ALTER DATABASE SyntheaHealth SET COMPATIBILITY_LEVEL = 160;
ALTER DATABASE SyntheaHealth SET QUERY_STORE = ON;
GO

IF SCHEMA_ID('stg')  IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('clin') IS NULL EXEC('CREATE SCHEMA clin');
IF SCHEMA_ID('slow') IS NULL EXEC('CREATE SCHEMA slow');
IF SCHEMA_ID('fast') IS NULL EXEC('CREATE SCHEMA fast');
GO
