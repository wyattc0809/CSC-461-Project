"""Loads .sql files, runs them against SQL Server, and measures what each one cost.

Cost is the change in the session's own counters (sys.dm_exec_sessions) before
vs. after the file runs, plus Python wall-clock time. Parsing STATISTICS IO/TIME
messages would also work, but the cursor in inefficient/02 would print ~100K of them.
"""
from __future__ import annotations

import re
import time
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
import pyodbc

_GO = re.compile(r"^\s*GO\s*$", re.IGNORECASE | re.MULTILINE)
_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_LINE_COMMENT = re.compile(r"--.*")

_SESSION_COUNTERS = """
SELECT cpu_time, logical_reads, reads, writes
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID;
"""


def count_loc(sql: str) -> int:
    """Lines of SQL code: non-blank lines once comments are removed.

    Both variants are written in the same formatting style, so this measures the
    query logic rather than how someone formats SQL.
    """
    sql = _BLOCK_COMMENT.sub("", sql)
    return sum(1 for line in sql.splitlines() if _LINE_COMMENT.sub("", line).strip())


@dataclass(frozen=True)
class SqlFile:
    path: Path

    @property
    def name(self) -> str:
        return self.path.stem                      # e.g. "03_utilization"

    @property
    def text(self) -> str:
        return self.path.read_text(encoding="utf-8")

    @property
    def batches(self) -> list[str]:
        """T-SQL batches. GO is a client-side separator, not T-SQL, so split on it here."""
        return [b for b in _GO.split(self.text) if b.strip()]

    @property
    def loc(self) -> int:
        return count_loc(self.text)


def load_sql_files(folder: Path) -> list[SqlFile]:
    """Every .sql file in a folder, in filename order (01_, 02_, ...)."""
    return [SqlFile(p) for p in sorted(folder.glob("*.sql"))]


@dataclass
class QueryMetrics:
    variant: str          # "inefficient" | "efficient"
    query: str            # file stem, e.g. "03_utilization"
    run: int              # 1..N benchmark repetition
    cold_cache: bool
    loc: int              # lines of SQL code
    wall_ms: float        # Python-side elapsed time
    cpu_ms: int           # server CPU time
    logical_reads: int    # 8 KB pages read from the buffer pool
    physical_reads: int   # 8 KB pages read from disk (non-zero mainly on cold runs)
    writes: int
    rows_returned: int | None


class SqlRunner:
    def __init__(self, conn_str: str):
        self.conn = pyodbc.connect(conn_str, autocommit=True)

    def close(self) -> None:
        self.conn.close()

    # -- helpers ---------------------------------------------------------------
    def _counters(self) -> tuple[int, int, int, int]:
        row = self.conn.cursor().execute(_SESSION_COUNTERS).fetchone()
        return row.cpu_time, row.logical_reads, row.reads, row.writes

    def clear_caches(self) -> None:
        """Cold-cache run: empty the buffer pool and plan cache. Dev container only!"""
        self.conn.cursor().execute("CHECKPOINT; DBCC DROPCLEANBUFFERS; DBCC FREEPROCCACHE;")

    def run_script(self, f: SqlFile) -> None:
        """Run a file without measuring it (schema setup)."""
        cur = self.conn.cursor()
        for batch in f.batches:
            cur.execute(batch)
            while cur.nextset():
                pass

    # -- main entry point --------------------------------------------------------
    def execute(
        self,
        f: SqlFile,
        variant: str,
        run: int = 1,
        cold_cache: bool = False,
        fetch: bool = False,
    ) -> tuple[QueryMetrics, pd.DataFrame | None]:
        """Run every batch in `f` and return (metrics, result set if fetch=True)."""
        if cold_cache:
            self.clear_caches()

        cur = self.conn.cursor()
        cur.execute("SET NOCOUNT ON;")

        cpu0, lr0, pr0, w0 = self._counters()
        start = time.perf_counter()

        df: pd.DataFrame | None = None
        for batch in f.batches:
            cur.execute(batch)
            while True:
                if fetch and cur.description:
                    columns = [col[0] for col in cur.description]
                    df = pd.DataFrame.from_records(cur.fetchall(), columns=columns)
                if not cur.nextset():
                    break

        wall_ms = (time.perf_counter() - start) * 1000
        cpu1, lr1, pr1, w1 = self._counters()

        metrics = QueryMetrics(
            variant=variant,
            query=f.name,
            run=run,
            cold_cache=cold_cache,
            loc=f.loc,
            wall_ms=round(wall_ms, 1),
            cpu_ms=cpu1 - cpu0,
            logical_reads=lr1 - lr0,
            physical_reads=pr1 - pr0,
            writes=w1 - w0,
            rows_returned=None if df is None else len(df),
        )
        return metrics, df
