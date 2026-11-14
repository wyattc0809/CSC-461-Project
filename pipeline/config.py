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


def connection_string(database: str = "SyntheaHealth") -> str:
    """ODBC connection string for the SQL Server container in docker-compose.yml."""
    return (
        "DRIVER={ODBC Driver 18 for SQL Server};"
        f"SERVER={os.getenv('MSSQL_HOST', 'localhost')},{os.getenv('MSSQL_PORT', '1433')};"
        f"DATABASE={database};"
        "UID=sa;"
        f"PWD={os.environ['MSSQL_SA_PASSWORD']};"
        "TrustServerCertificate=yes;"
    )
