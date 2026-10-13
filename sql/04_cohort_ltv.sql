-- 04 · Cumulative LTV per cohort (GMV per acquired customer).
-- Grain: cohort_month x month_number (0..11, only observable cells).
-- ltv at month_number = 11 is the 12-month LTV used as the CAC ceiling.

CREATE OR REPLACE TABLE olist_mart.cohort_ltv AS
WITH monthly AS (
  SELECT
    cohort_month,
    month_number,
    cohort_customers,
    revenue
  FROM olist_mart.cohort_retention
  WHERE month_number <= 11
)

SELECT
  cohort_month,
  month_number,
  cohort_customers,
  SUM(revenue) OVER (
    PARTITION BY cohort_month
    ORDER BY month_number
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )                                                         AS cumulative_revenue,
  ROUND(SAFE_DIVIDE(
    SUM(revenue) OVER (
      PARTITION BY cohort_month
      ORDER BY month_number
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ),
    cohort_customers
  ), 2)                                                     AS ltv,
  -- cohorts up to 2017-09 have all 12 months observed before the cutoff
  cohort_month <= DATE '2017-09-01'                         AS has_full_12m
FROM monthly;
