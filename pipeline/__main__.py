"""Entry point:  python -m pipeline [--setup] [--runs N] [--cold]

  1. (optional) create the database, load the CSVs, build indexes
  2. for each SQL variant (inefficient, efficient):
       run its query folder N times and keep the metrics
       train the admission model on the training set it produced
  3. assert both training sets are identical
  4. write results/report.md comparing query cost and model results
"""
from __future__ import annotations

import argparse

from . import config
from .equivalence import assert_equivalent
from .features import build_training_set
from .model import AdmissionRateModel, time_split
from .report import model_comparison, query_comparison, write_report
from .sql_runner import SqlRunner, load_sql_files


def setup_database() -> None:
    print("Setting up database ...")
    runner = SqlRunner(config.connection_string(database="master"))
    data_dir = config.DATA_DIR.rstrip("/\\")
    sep = "\\" if "\\" in data_dir or ":" in data_dir else "/"
    replacements = {"'/data/": f"'{data_dir}{sep}"}
    print(f"  CSV folder (as seen by SQL Server): {data_dir}")
    try:
        for f in load_sql_files(config.SCHEMA_DIR):
            print(f"  running {f.name}")
            runner.run_script(f, replacements)
    finally:
        runner.close()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--setup", action="store_true", help="create the DB and load the CSVs first")
    parser.add_argument("--runs", type=int, default=config.BENCHMARK_RUNS)
    parser.add_argument("--cold", action="store_true", help="clear caches before every query")
    args = parser.parse_args()

    if args.setup:
        setup_database()

    runner = SqlRunner(config.connection_string())
    all_metrics = []
    training_sets = {}
    model_results = {}

    try:
        for variant, query_dir in config.QUERY_DIRS.items():
            print(f"\n=== {variant.upper()} SQL ({query_dir.relative_to(config.ROOT)}) ===")
            for run in range(1, args.runs + 1):
                df, metrics = build_training_set(runner, query_dir, variant, run=run, cold_cache=args.cold)
                all_metrics.extend(metrics)
            training_sets[variant] = df        # last run's output; every run returns the same rows

            # Identical model code and seed for both variants
            train, test = time_split(df, config.TRAIN_END)
            model = AdmissionRateModel(seed=config.RANDOM_SEED).fit(train)
            model_results[variant] = model.evaluate(test)
            print(f"  model: {model_results[variant]}")
    finally:
        runner.close()

    print("\n=== Equivalence check ===")
    fp = assert_equivalent(training_sets["inefficient"], training_sets["efficient"])
    print(f"  PASS: training sets identical (fingerprint {fp})")

    report = write_report(
        query_table=query_comparison(all_metrics),
        model_table=model_comparison(model_results),
        fingerprint=fp,
        n_rows=len(training_sets["efficient"]),
        raw_metrics=all_metrics,
        out_dir=config.RESULTS_DIR,
    )
    print(f"\nReport written to {report.relative_to(config.ROOT)}")


if __name__ == "__main__":
    main()
