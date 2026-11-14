# Running the experiment

How to set up the database and benchmark the inefficient and efficient SQL against each
other. For the terms used here, see [glossary.md](glossary.md).

> **Status:** the pipeline has not yet been run against a real database. Expect a few
> fixes during the first `--setup` run.

## Why Docker

The queries are T-SQL, so they need Microsoft SQL Server. [docker-compose.yml](../docker-compose.yml)
gives everyone the same server:

- **One-command install.** `docker compose up -d` starts SQL Server 2022. No full SQL
  Server install is needed.
- **The same conditions for everyone.** The SQL Server version (2022 CU16), the CPU and
  memory limits (4 CPUs, 6 GB) and the dataset mount (`/data`) are all fixed. Timings
  can then be compared across machines, although laptop hardware still differs.
- **A safe sandbox.** Cold-cache runs clear the server's memory and plan cache. Never do
  that on a shared server. In a throwaway container it's harmless.

You can use another SQL Server instead by pointing `MSSQL_HOST` and `MSSQL_PORT` in
`.env` at it. The setup scripts read the CSVs from `/data`, so that path would need to
change too.

## Prerequisites

- Docker Desktop (needs WSL2 on Windows)
- Python 3.11
- Microsoft **ODBC Driver 18 for SQL Server**, which `pyodbc` needs to connect

## Get the dataset

The CSVs are not in git because they're too large for GitHub. Get the dataset zip from
the team and extract it into `Synthea_Healthcare_Dataset/`. See
[the dataset README](../Synthea_Healthcare_Dataset/README.md) for the five files the
pipeline needs.

## Steps

Run these from the repo root.

**1. Configure and start SQL Server**

```bash
cp .env.example .env        # PowerShell / cmd: copy .env.example .env
docker compose up -d
pip install -r requirements.txt
```

In `.env`, set `MSSQL_SA_PASSWORD` to a strong password: 8+ characters, with upper
case, lower case, a digit and a symbol. `.env` is gitignored, so never commit it.

**2. Load the database (first time only)**

```bash
python -m pipeline --setup --runs 1
```

This runs `sql/schema/00` to `04`, which:

- create the `SyntheaHealth` database
- bulk-load the CSVs
- build the typed `clin.*` tables, the indexes and the UDF

It then does one benchmark pass as a smoke test.

**3. Run the benchmark, warm and cold**

```bash
python -m pipeline --runs 5          # warm: data already in memory
python -m pipeline --runs 5 --cold   # cold: caches cleared before every query
```

The two modes answer different questions:

- **Warm** isolates the effect of query shape: SARGability, cursors vs. set-based code,
  correlated subqueries.
- **Cold** adds disk I/O, which is closer to a first-time run.

The results go to `results/report.md`.

## What gets measured

For each `.sql` file, [pipeline/sql_runner.py](../pipeline/sql_runner.py) records:

| Metric | Meaning |
|---|---|
| `wall_ms` | elapsed time seen by Python |
| `cpu_ms` | server CPU time |
| `logical_reads` | 8 KB pages read from memory |
| `physical_reads` | 8 KB pages read from disk (mainly on cold runs) |
| `writes` | pages written |
| `loc` | lines of SQL, without blank lines or comments |

The server metrics are the change in the session's own counters in
`sys.dm_exec_sessions`, read before and after each file runs. Each file runs N times and
the report uses the **median**.

`results/report.md` contains:

1. **Query cost table:** one row per query file plus a TOTAL row, with the speedup.
2. **Model table:** AUROC, PR-AUC, Brier score and monthly-rate MAE for each version,
   with an `identical` column. Every value must be `True`.
3. **Fingerprint:** a hash of the training set. It must be the same for both versions.

If the two training sets differ, the run stops. A speed comparison only counts when both
versions produce the same data.

## Getting reliable numbers

- **Use `--runs 5` or more.** The first run includes plan compilation. With `--cold`,
  every run recompiles.
- **Leave the machine alone during runs.** Close other heavy programs, because wall-clock
  time is affected by everything else running.
- **Cite logical reads and CPU time first.** They change less between machines than wall
  time does.
- **Run order:** [pipeline/\_\_main\_\_.py](../pipeline/__main__.py) currently does all
  inefficient runs first and then all efficient runs. Anything that drifts during the
  session, like tempdb or log growth, affects one side more. Alternating the versions
  would be a fairer design.
- **Explain results with execution plans.** Run a query in SSMS or Azure Data Studio
  with "Include Actual Execution Plan" to see why it is fast or slow (seeks vs. scans,
  join types, row estimates).

## Still to do

- [ ] Get Docker and the ODBC driver working on at least one machine
- [ ] Do the first real `--setup` run and fix what breaks
- [ ] Confirm the equivalence check passes
- [ ] Decide whether to alternate the run order
- [ ] Collect warm and cold reports for the write-up
