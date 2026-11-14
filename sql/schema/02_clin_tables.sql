/* =============================================================================
   02_clin_tables.sql
   Typed copies of the staging tables. Both query variants read from these, so
   any speed difference comes from how the query is written, not from the data.

   Type choices (also a storage experiment):
     UUIDs  -> UNIQUEIDENTIFIER (16 bytes)  instead of NVARCHAR(36) (72 bytes)
     ISO timestamps "2022-02-08T12:41:56Z" -> DATETIME2(0) via style 127
   ========================================================================== */
USE SyntheaHealth;
GO

DROP TABLE IF EXISTS clin.observations, clin.medications, clin.conditions,
                     clin.encounters, clin.patients;
GO

CREATE TABLE clin.patients (
    Id                  UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_patients PRIMARY KEY,
    BIRTHDATE           DATE             NOT NULL,
    DEATHDATE           DATE             NULL,
    GENDER              CHAR(1)          NOT NULL,
    RACE                VARCHAR(20)      NULL,
    ETHNICITY           VARCHAR(20)      NULL,
    INCOME              INT              NULL,
    HEALTHCARE_COVERAGE DECIMAL(12,2)    NULL
);

CREATE TABLE clin.encounters (
    Id             UNIQUEIDENTIFIER NOT NULL CONSTRAINT pk_encounters PRIMARY KEY NONCLUSTERED,
    START          DATETIME2(0)     NOT NULL,
    STOP           DATETIME2(0)     NULL,
    PATIENT        UNIQUEIDENTIFIER NOT NULL CONSTRAINT fk_enc_patient REFERENCES clin.patients (Id),
    ORGANIZATION   UNIQUEIDENTIFIER NULL,
    PROVIDER       UNIQUEIDENTIFIER NULL,
    PAYER          UNIQUEIDENTIFIER NULL,
    ENCOUNTERCLASS VARCHAR(20)      NOT NULL,
    CODE           VARCHAR(20)      NULL,
    DESCRIPTION    VARCHAR(255)     NULL,
    TOTAL_CLAIM_COST DECIMAL(12,2)  NULL
);

CREATE TABLE clin.conditions (
    START       DATE             NOT NULL,
    STOP        DATE             NULL,
    PATIENT     UNIQUEIDENTIFIER NOT NULL REFERENCES clin.patients (Id),
    ENCOUNTER   UNIQUEIDENTIFIER NULL,
    CODE        VARCHAR(20)      NOT NULL,
    DESCRIPTION VARCHAR(255)     NULL
);

CREATE TABLE clin.medications (
    START       DATETIME2(0)     NOT NULL,
    STOP        DATETIME2(0)     NULL,
    PATIENT     UNIQUEIDENTIFIER NOT NULL REFERENCES clin.patients (Id),
    ENCOUNTER   UNIQUEIDENTIFIER NULL,
    CODE        VARCHAR(20)      NOT NULL,
    DESCRIPTION VARCHAR(255)     NULL
);

CREATE TABLE clin.observations (
    DATE        DATETIME2(0)     NOT NULL,
    PATIENT     UNIQUEIDENTIFIER NOT NULL REFERENCES clin.patients (Id),
    ENCOUNTER   UNIQUEIDENTIFIER NULL,
    CATEGORY    VARCHAR(30)      NULL,
    CODE        VARCHAR(20)      NOT NULL,
    DESCRIPTION VARCHAR(255)     NULL,
    VALUE       VARCHAR(255)     NULL,          -- raw text (labs can be non-numeric)
    VALUE_NUM   DECIMAL(10,2)    NULL,          -- parsed once at load time
    UNITS       VARCHAR(30)      NULL
);
GO

INSERT INTO clin.patients WITH (TABLOCK)
SELECT TRY_CONVERT(UNIQUEIDENTIFIER, Id),
       TRY_CONVERT(DATE, BIRTHDATE),
       TRY_CONVERT(DATE, NULLIF(DEATHDATE, '')),
       GENDER, RACE, ETHNICITY,
       TRY_CONVERT(INT, REPLACE(INCOME, CHAR(13), '')),
       TRY_CONVERT(DECIMAL(12,2), HEALTHCARE_COVERAGE)
FROM stg.patients;

INSERT INTO clin.encounters WITH (TABLOCK)
SELECT TRY_CONVERT(UNIQUEIDENTIFIER, Id),
       TRY_CONVERT(DATETIME2(0), START, 127),
       TRY_CONVERT(DATETIME2(0), NULLIF(STOP, ''), 127),
       TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT),
       TRY_CONVERT(UNIQUEIDENTIFIER, ORGANIZATION),
       TRY_CONVERT(UNIQUEIDENTIFIER, PROVIDER),
       TRY_CONVERT(UNIQUEIDENTIFIER, PAYER),
       ENCOUNTERCLASS, CODE, DESCRIPTION,
       TRY_CONVERT(DECIMAL(12,2), TOTAL_CLAIM_COST)
FROM stg.encounters;

INSERT INTO clin.conditions WITH (TABLOCK)
SELECT TRY_CONVERT(DATE, START),
       TRY_CONVERT(DATE, NULLIF(STOP, '')),
       TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT),
       TRY_CONVERT(UNIQUEIDENTIFIER, ENCOUNTER),
       CODE,
       REPLACE(DESCRIPTION, CHAR(13), '')
FROM stg.conditions;

INSERT INTO clin.medications WITH (TABLOCK)
SELECT TRY_CONVERT(DATETIME2(0), START, 127),
       TRY_CONVERT(DATETIME2(0), NULLIF(STOP, ''), 127),
       TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT),
       TRY_CONVERT(UNIQUEIDENTIFIER, ENCOUNTER),
       CODE, DESCRIPTION
FROM stg.medications;

INSERT INTO clin.observations WITH (TABLOCK)
SELECT TRY_CONVERT(DATETIME2(0), DATE, 127),
       TRY_CONVERT(UNIQUEIDENTIFIER, PATIENT),
       TRY_CONVERT(UNIQUEIDENTIFIER, ENCOUNTER),
       CATEGORY, CODE, DESCRIPTION, VALUE,
       CASE WHEN REPLACE(TYPE, CHAR(13), '') = 'numeric' THEN TRY_CONVERT(DECIMAL(10,2), VALUE) END,
       UNITS
FROM stg.observations;
GO
