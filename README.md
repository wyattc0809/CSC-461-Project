# CSC-461-Project

Efficient T-SQL querying for a healthcare admissions pipeline.

The same admission-rate model is fed by two folders of SQL that produce **identical
training data**: one written with common anti-patterns, one written efficiently. The
model results match exactly. Only the query cost differs: time, CPU, page reads and
lines of SQL.

> **Status: mock / skeleton.** The code shows the intended structure and has not yet
> been run against the database.

## How it fits together

```
Synthea CSVs ──BULK INSERT──► stg.* ──typed load──► clin.*  (shared by both variants)
                                                       │
                     ┌─────────────────────────────────┴─────────────────────────────┐
     sql/queries/inefficient/01..06.sql                          sql/queries/efficient/01..06.sql
                     │  (writes slow.*)                                (writes fast.*) │
                     ▼                                                                 ▼
            training set A ───────────► equivalence check (must be identical) ◄──── training set B
                     │                                                                 │
                     ▼                                                                 ▼
         AdmissionRateModel(seed=461)                                AdmissionRateModel(seed=461)
                     └──────────────► results/report.md: cost differs, metrics identical ◄──┘
```

## What the model predicts

- **Admission** = an encounter with `ENCOUNTERCLASS` of `inpatient` or `emergency`
  (3,764 in the dataset).
- **Row** = one patient at the start of one month, Jan 2017 to Sep 2026 (about 100K rows).
- **Label** = the patient is admitted within the next 30 days.
- **Admission rate** = the sum of predicted probabilities ÷ patients alive that month,
  expressed per 1,000 patients.
- **Features:**
  - age, gender, income
  - prior admissions (365 days), ED visits (90 days), all visits (365 days),
    days since the last admission
  - active conditions, active medications, latest BMI
  - month of year

## The query pairs

| File | Inefficient pattern | Efficient rewrite | LOC (ineff / eff) |
|---|---|---|---|
| `01_admissions` | `SELECT *`, `YEAR(START)`, `LOWER(..) OR ..` | column list, date range, `IN` matching the filtered index | 7 / 8 |
| `02_snapshots` | cursor + nested `WHILE` loop, `NVARCHAR(36)` ids | set-based month list + one join | 21 / 15 |
| `03_utilization` | 4 correlated subqueries, `CONVERT` on a key, `DATEDIFF` filter | one range join + conditional aggregation | 27 / 19 |
| `04_clinical` | correlated subqueries, `ISNULL(STOP,..)`, `RTRIM(CODE) = N'..'`, text parsed per row | pre-aggregated CTEs + `OUTER APPLY TOP 1` index seek | 23 / 34 |
| `05_labels` | insert all rows, then `UPDATE` with `COUNT(*) > 0` | one pass with `EXISTS` | 13 / 15 |
| `06_training_set` | comma joins, scalar UDF, needless `DISTINCT` | ANSI joins, inline expression | 22 / 24 |
| **Total** | | | **113 / 115** |

LOC = non-blank lines once comments are removed (`count_loc` in
[pipeline/sql_runner.py](pipeline/sql_runner.py)). The efficient SQL is **not shorter
overall**, so the speedup comes from what the optimizer can do with the query, not from
writing less code.

## Repository layout

```
docker-compose.yml           SQL Server 2022 container (dataset mounted at /data)
sql/schema/                  00 create DB → 01 stage + BULK INSERT → 02 typed tables → 03 indexes → 04 UDF
sql/queries/inefficient/     01..06: anti-pattern versions (write slow.*)
sql/queries/efficient/       01..06: efficient versions   (write fast.*)
pipeline/
  config.py                  paths, connection string, seed, train/test cutoff
  sql_runner.py              loads .sql files, splits on GO, measures CPU/reads/time, counts LOC
  features.py                runs a query folder in order → training-set DataFrame + metrics
  equivalence.py             proves both training sets are identical (and fingerprints them)
  model.py                   AdmissionRateModel: gradient boosting + monthly rate aggregation
  report.py                  comparison tables → results/report.md
  __main__.py                orchestration
```

## Docs

- [docs/running-the-experiment.md](docs/running-the-experiment.md): setup, why we use
  Docker, how to benchmark, what gets measured, and how to get reliable numbers
- [docs/glossary.md](docs/glossary.md): SQL and benchmarking terms used in this project

## Running it (once Docker is available)

See [docs/running-the-experiment.md](docs/running-the-experiment.md) for the full guide.

```bash
cp .env.example .env                 # Windows: copy .env.example .env; then set MSSQL_SA_PASSWORD
docker compose up -d
pip install -r requirements.txt      # also needs "ODBC Driver 18 for SQL Server"
python -m pipeline --setup --runs 5  # first run: create DB + load CSVs
python -m pipeline --runs 5 --cold   # benchmark with caches cleared before every query
```

## Output: `results/report.md`

1. **Query cost table:** one row per query file plus a TOTAL row.
   - Columns: LOC, median ms, CPU ms and logical reads for each variant, plus speedup.
2. **Model table:** AUROC, PR-AUC, Brier score and monthly-rate MAE for each variant,
   with an `identical` column. Every value in it must be `True`.
3. **Fingerprint:** a hash of the training set, the same for both variants.
