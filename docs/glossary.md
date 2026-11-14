# Glossary

Terms to know before working on the queries or reading the report. The most important
ones for the paper are **SARGable**, **seek vs. scan**, **row-by-row vs. set-based**,
**execution plan** and **logical reads**. Most of our results are explained with them.

## Database setup

- **Schema:** a named group of tables inside a database. We use four:
  - `stg`: raw CSV data as loaded
  - `clin`: cleaned tables with proper data types
  - `slow`: outputs of the inefficient queries
  - `fast`: outputs of the efficient queries
- **BULK INSERT:** loads a whole CSV file into a table in one command.
- **Data types:** `UNIQUEIDENTIFIER` is a 16-byte ID type, while `NVARCHAR(36)` stores
  the same ID as text.
- **Implicit conversion:** what happens when columns of different types are compared.
  SQL Server converts one of them on every row, which is slow and can block index use.
- **`GO`:** separates batches in a script. SQL Server doesn't understand it; the client
  tool (here, our Python runner) splits the script on it.

## Indexes

- **Index:** a sorted lookup structure on one or more columns, like a book's index.
- **Clustered index:** the table itself is stored in this sorted order. A table can have
  only one.
- **Nonclustered index:** a separate sorted copy of some columns that points back to the
  full rows.
- **Filtered index:** an index that covers only the rows matching a condition, e.g.
  `WHERE ENCOUNTERCLASS IN ('inpatient', 'emergency')`.
- **Covering index:** contains every column a query needs, so SQL Server never has to
  look up the full row.
- **Seek vs. scan:**
  - A **seek** jumps straight to the matching rows (fast).
  - A **scan** reads the whole table or index (slow on large tables).

## Why queries get slow (our anti-patterns)

- **SARGable:** "Search ARGument-able". A condition is SARGable when an index can be used
  to seek on it.
  - `WHERE START >= '2016-01-01'` is SARGable.
  - `WHERE YEAR(START) >= 2016` is not, because a function wrapped around the column
    blocks the index.
- **Row-by-row vs. set-based:**
  - A **cursor** or `WHILE` loop handles one row at a time.
  - One **set-based** statement lets the optimizer process every row at once.
- **Correlated subquery:** a subquery that refers to the outer query, so it can run again
  for every outer row.
- **`SELECT *`:** reads columns that nothing downstream uses.
- **Scalar UDF:** a user-defined function that is called once per row and hides its
  logic from the optimizer.
- **`EXISTS` vs. `COUNT(*) > 0`:** `EXISTS` stops at the first match. `COUNT` counts
  every match.
- **Needless `DISTINCT`:** makes SQL Server sort or hash the results to remove duplicates
  that don't exist.

## Efficient patterns we use

- **CTE (`WITH ...`):** a named temporary result you can use inside one query.
- **Conditional aggregation:** `SUM(CASE WHEN ... THEN 1 ELSE 0 END)` computes several
  counts in a single pass.
- **`OUTER APPLY TOP 1`:** gets one row per outer row, e.g. "latest BMI before this
  date", and can seek on an index.
- **ANSI joins:** explicit `JOIN ... ON ...` instead of comma-separated tables in `FROM`.

## How SQL Server runs a query

- **Query optimizer:** chooses how to run a query: which indexes to use, which join
  method, and in what order.
- **Execution plan:** the optimizer's chosen strategy. View it in SSMS or Azure Data
  Studio with "Include Actual Execution Plan". This is how we explain *why* one version
  is faster.
- **Plan cache:** where compiled plans are stored and reused. The first run of a query
  includes compile time.
- **Buffer pool:** data pages cached in memory.

## What we measure

- **Page:** SQL Server's 8 KB storage unit.
- **Logical reads:** pages read from memory. This is the main measure of how much work a
  query does.
- **Physical reads:** pages read from disk. These mostly show up on cold runs.
- **CPU time:** how long the server spent computing.
- **Wall-clock time:** the elapsed time we see, including waiting.
- **Warm vs. cold cache:**
  - **Warm** means the data is already in memory.
  - **Cold** means memory and plans were cleared first (`DBCC DROPCLEANBUFFERS`,
    `DBCC FREEPROCCACHE`).
- **Median of N runs:** we report the median so one unusual run doesn't skew the result.

## Experiment validity

- **Equivalence:** both versions must produce exactly the same rows. Otherwise we'd be
  comparing different work.
- **Controlled environment:** the Docker resource limits, plus not running other heavy
  programs during a benchmark.
- **Fixed seed (461):** makes model training reproducible.
- **Time split:** the model trains on snapshots before 2024-01-01 and is tested on the
  rest, so it is never trained on the future.

## Model metrics (enough to read the report)

- **AUROC, PR-AUC:** how well the model ranks admitted patients above non-admitted ones.
  Higher is better.
- **Brier score:** how accurate the predicted probabilities are. Lower is better.
- **MAE:** the average error of the predicted monthly admission rate. Lower is better.
