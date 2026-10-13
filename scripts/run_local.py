"""Run the BigQuery SQL pipeline locally on DuckDB.

The files in /sql are written in BigQuery Standard SQL (the production target).
This script transpiles them to DuckDB with sqlglot so the whole pipeline can be
reproduced and checked offline, then exports the dashboard tables to /outputs.

Usage:
    python scripts/run_local.py
"""
import sys
from pathlib import Path

import duckdb
import sqlglot

ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "data" / "raw"
SQL_DIR = ROOT / "sql"
OUT_DIR = ROOT / "outputs"
DB_PATH = ROOT / "data" / "olist.duckdb"

RAW_TABLES = {
    "orders": "olist_orders_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "customers": "olist_customers_dataset.csv",
}
EXPORT_TABLES = [
    "kpi_summary",
    "cohort_retention",
    "cohort_ltv",
    "segment_ltv",
    "repurchase_curve",
]


def load_raw(con: duckdb.DuckDBPyConnection) -> None:
    con.execute("CREATE SCHEMA IF NOT EXISTS olist_raw")
    con.execute("CREATE SCHEMA IF NOT EXISTS olist_mart")
    for table, file_name in RAW_TABLES.items():
        path = RAW_DIR / file_name
        if not path.exists():
            sys.exit(f"Missing {path}. Download the Olist dataset first (see README).")
        con.execute(
            f"CREATE OR REPLACE TABLE olist_raw.{table} AS "
            f"SELECT * FROM read_csv_auto('{path.as_posix()}')"
        )


def run_sql_file(con: duckdb.DuckDBPyConnection, path: Path):
    statements = sqlglot.transpile(
        path.read_text(encoding="utf-8"), read="bigquery", write="duckdb"
    )
    result = None
    for statement in statements:
        result = con.execute(statement)
    return result


def main() -> None:
    OUT_DIR.mkdir(exist_ok=True)
    con = duckdb.connect(str(DB_PATH))
    load_raw(con)

    model_files = sorted(p for p in SQL_DIR.glob("*.sql") if not p.name.startswith("99"))
    for path in model_files:
        run_sql_file(con, path)
        print(f"ok  {path.name}")

    checks = run_sql_file(con, SQL_DIR / "99_quality_checks.sql").fetchall()
    failed = [(name, n) for name, n in checks if n]
    for name, n in checks:
        print(f"{'FAIL' if n else 'pass'}  {name} ({n})")

    for table in EXPORT_TABLES:
        con.execute(
            f"COPY olist_mart.{table} TO '{(OUT_DIR / f'{table}.csv').as_posix()}' (HEADER)"
        )
    print(f"exported {len(EXPORT_TABLES)} tables to {OUT_DIR}")

    if failed:
        sys.exit(f"{len(failed)} quality check(s) failed")


if __name__ == "__main__":
    main()
