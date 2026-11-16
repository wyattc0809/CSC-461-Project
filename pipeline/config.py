"""Paths, connection settings and experiment constants."""
import os
from pathlib import Path

from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
load_dotenv(ROOT / ".env")

SQL_DIR = ROOT / "sql"
SCHEMA_DIR = SQL_DIR / "schema"
QUERY_DIRS = {
    "inefficient": SQL_DIR / "queries" / "inefficient",
    "efficient": SQL_DIR / "queries" / "efficient",
}
RESULTS_DIR = ROOT / "results"

RANDOM_SEED = 461
TRAIN_END = "2024-01-01"   # snapshots before this date train the model; the rest test it
BENCHMARK_RUNS = 5         # each variant's SQL is run this many times; medians are reported


# Folder the SQL Server *service* reads the CSVs from (BULK INSERT runs server-side).
# Docker mounts the dataset at /data. For a local Windows install, copy the CSVs to a
# folder the service account can read (e.g. C:\SyntheaData) and set MSSQL_DATA_DIR.
DATA_DIR = os.getenv("MSSQL_DATA_DIR", "/data")


def connection_string(database: str = "SyntheaHealth") -> str:
    """ODBC connection string.

    With MSSQL_SA_PASSWORD set: SQL login as sa (the Docker container).
    Without it: Windows authentication (a local SQL Server install).
    """
    password = os.getenv("MSSQL_SA_PASSWORD")
    auth = f"UID=sa;PWD={password};" if password else "Trusted_Connection=yes;"
    # MSSQL_PORT left empty -> connect by host name only (local shared memory / named pipes,
    # for installs where TCP 1433 is not enabled).
    port = os.getenv("MSSQL_PORT", "1433")
    server = os.getenv("MSSQL_HOST", "localhost") + (f",{port}" if port else "")
    return (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"{auth}"
        "TrustServerCertificate=yes;"
    )
