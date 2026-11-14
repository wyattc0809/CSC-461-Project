"""Builds the inefficient-vs-efficient comparison tables and writes them to results/."""
from __future__ import annotations

from dataclasses import asdict
from pathlib import Path

import pandas as pd

from .sql_runner import QueryMetrics


def query_comparison(metrics: list[QueryMetrics]) -> pd.DataFrame:
    """One row per query: LOC, median time and median reads for each variant, plus speedup."""
    raw = pd.DataFrame(asdict(m) for m in metrics)
    med = (
        raw.groupby(["query", "variant"])
        .agg(loc=("loc", "first"),
             wall_ms=("wall_ms", "median"),
             cpu_ms=("cpu_ms", "median"),
             logical_reads=("logical_reads", "median"))
        .unstack("variant")
    )

    table = pd.DataFrame({
        "LOC (ineff)":     med[("loc", "inefficient")],
        "LOC (eff)":       med[("loc", "efficient")],
        "ms (ineff)":      med[("wall_ms", "inefficient")],
        "ms (eff)":        med[("wall_ms", "efficient")],
        "CPU ms (ineff)":  med[("cpu_ms", "inefficient")],
        "CPU ms (eff)":    med[("cpu_ms", "efficient")],
        "reads (ineff)":   med[("logical_reads", "inefficient")],
        "reads (eff)":     med[("logical_reads", "efficient")],
    })
    table.loc["TOTAL"] = table.sum()
    table["speedup"] = (table["ms (ineff)"] / table["ms (eff)"]).round(1).astype(str) + "x"
    table["LOC delta"] = table["LOC (eff)"] - table["LOC (ineff)"]
    return table


def model_comparison(results: dict[str, dict[str, float]]) -> pd.DataFrame:
    """Model metrics side by side. These must be identical; that's the point."""
    table = pd.DataFrame(results).round(6)
    table["identical"] = table["inefficient"] == table["efficient"]
    return table


def write_report(
    query_table: pd.DataFrame,
    model_table: pd.DataFrame,
    fingerprint: str,
    n_rows: int,
    raw_metrics: list[QueryMetrics],
    out_dir: Path,
) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(asdict(m) for m in raw_metrics).to_csv(out_dir / "benchmark_raw.csv", index=False)
    query_table.to_csv(out_dir / "query_comparison.csv")
    model_table.to_csv(out_dir / "model_comparison.csv")

    report = out_dir / "report.md"
    report.write_text(
        "# Inefficient vs. efficient SQL: admissions pipeline\n\n"
        f"Training set: **{n_rows:,} rows**, identical for both variants "
        f"(fingerprint `{fingerprint}`).\n\n"
        "## Query cost (median of runs)\n\n"
        f"{query_table.to_markdown()}\n\n"
        "## Model results (same features, same seed, so they should match exactly)\n\n"
        f"{model_table.to_markdown()}\n",
        encoding="utf-8",
    )
    return report
