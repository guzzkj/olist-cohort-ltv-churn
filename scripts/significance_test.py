"""Two-proportion z-test: is the repurchase gap between payment segments real?

Compares the 12-month repurchase rate of customers whose first order was paid
in 4+ credit-card installments against everyone else (cohorts Jan-Sep 2017).

Usage (after scripts/run_local.py):
    python scripts/significance_test.py
"""
import math
from pathlib import Path

import duckdb

DB_PATH = Path(__file__).resolve().parents[1] / "data" / "olist.duckdb"

QUERY = """
SELECT
  payment_segment IN ('credit_card 4-6x', 'credit_card 7x+') AS is_high_installment,
  COUNT(*)                                                    AS customers,
  COUNT_IF(days_to_2nd_order <= 365)                          AS repeaters
FROM olist_mart.customers
WHERE has_full_12m
GROUP BY 1
"""


def two_proportion_z(k1: int, n1: int, k2: int, n2: int) -> tuple[float, float]:
    pooled = (k1 + k2) / (n1 + n2)
    se = math.sqrt(pooled * (1 - pooled) * (1 / n1 + 1 / n2))
    z = (k1 / n1 - k2 / n2) / se
    p_value = math.erfc(abs(z) / math.sqrt(2))
    return z, p_value


def main() -> None:
    con = duckdb.connect(str(DB_PATH), read_only=True)
    groups = {flag: (n, k) for flag, n, k in con.execute(QUERY).fetchall()}
    (n1, k1), (n2, k2) = groups[True], groups[False]
    z, p_value = two_proportion_z(k1, n1, k2, n2)
    print(f"4+ installments: {k1}/{n1} = {k1 / n1:.2%}")
    print(f"everyone else:   {k2}/{n2} = {k2 / n2:.2%}")
    print(f"relative lift:   {(k1 / n1) / (k2 / n2) - 1:+.0%}")
    print(f"z = {z:.2f}, two-sided p = {p_value:.4f}")


if __name__ == "__main__":
    main()
