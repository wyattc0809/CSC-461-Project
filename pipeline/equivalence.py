"""Proves that the inefficient and efficient SQL produced the same training set.

If this check passes, any difference in model results would have to come from the
model code, and that code is identical for both variants, so the model results must
match. The only thing left that differs between the variants is cost (time, reads, LOC).
"""
from __future__ import annotations

import hashlib

import pandas as pd

KEY = ["patient_id", "snapshot_date"]


class NotEquivalentError(AssertionError):
    pass


def normalize(df: pd.DataFrame) -> pd.DataFrame:
    """Remove differences that don't count as different data (row order, GUID letter case)."""
    out = df.copy()
    out["patient_id"] = out["patient_id"].astype(str).str.lower()
    return out.sort_values(KEY, kind="mergesort").reset_index(drop=True)


def fingerprint(df: pd.DataFrame) -> str:
    """Short, stable hash of the whole table, printed in the report as proof."""
    hashed = pd.util.hash_pandas_object(normalize(df), index=False).values
    return hashlib.sha256(hashed.tobytes()).hexdigest()[:16]


def assert_equivalent(a: pd.DataFrame, b: pd.DataFrame) -> str:
    """Raise NotEquivalentError if a and b differ in any way; otherwise return the shared fingerprint."""
    a, b = normalize(a), normalize(b)

    if list(a.columns) != list(b.columns):
        raise NotEquivalentError(f"Column mismatch:\n  {list(a.columns)}\n  {list(b.columns)}")
    if len(a) != len(b):
        raise NotEquivalentError(f"Row count mismatch: {len(a):,} vs {len(b):,}")

    diff = a.compare(b)                       # empty DataFrame when identical
    if not diff.empty:
        cols = sorted({c for c, _ in diff.columns})
        raise NotEquivalentError(
            f"{len(diff):,} rows differ in columns {cols}. First differences:\n{diff.head(10)}"
        )

    return fingerprint(a)
