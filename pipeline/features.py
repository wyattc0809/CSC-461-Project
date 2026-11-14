"""Turns a folder of SQL files into the model's training set.

The contract for a query folder:
  - files run in name order (01_ ... 06_)
  - every file except the last one builds intermediate tables
  - the last file returns the training set, one row per (patient_id, snapshot_date)

So "which SQL is used" is just a folder path; nothing else in the pipeline changes.
"""
from __future__ import annotations

from pathlib import Path

import pandas as pd

from .sql_runner import QueryMetrics, SqlRunner, load_sql_files


def build_training_set(
    runner: SqlRunner,
    query_dir: Path,
    variant: str,
    run: int = 1,
    cold_cache: bool = False,
) -> tuple[pd.DataFrame, list[QueryMetrics]]:
    files = load_sql_files(query_dir)
    if not files:
        raise FileNotFoundError(f"No .sql files in {query_dir}")

    *build_steps, final_step = files
    metrics: list[QueryMetrics] = []

    for f in build_steps:
        m, _ = runner.execute(f, variant, run=run, cold_cache=cold_cache)
        metrics.append(m)
        print(f"  [{variant:<11}] run {run}  {f.name:<18} {m.wall_ms:>10,.0f} ms  {m.logical_reads:>12,} reads")

    m, df = runner.execute(final_step, variant, run=run, cold_cache=cold_cache, fetch=True)
    metrics.append(m)
    print(f"  [{variant:<11}] run {run}  {final_step.name:<18} {m.wall_ms:>10,.0f} ms  {m.rows_returned:,} rows")

    return df, metrics
