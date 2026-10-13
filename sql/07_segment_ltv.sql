-- 07 · Fintech hook: does the way the first order was paid change repurchase and LTV?
-- Grain: payment_segment (+ an 'all' row).
-- Only cohorts with a full 12-month window (2017-01..2017-09) so LTV-12 is comparable.

CREATE OR REPLACE TABLE olist_mart.segment_ltv AS
WITH base AS (
  SELECT *
  FROM olist_mart.customers
  WHERE has_full_12m
),

by_segment AS (
  SELECT
    payment_segment,
    COUNT(*)                                                         AS customers,
    ROUND(AVG(first_order_value), 2)                                 AS avg_first_order_value,
    ROUND(AVG(ltv_12m), 2)                                           AS ltv_12m,
    ROUND(COUNTIF(days_to_2nd_order <= 365) / COUNT(*) * 100, 2)     AS repeat_rate_12m_pct,
    ROUND(SAFE_DIVIDE(SUM(ltv_12m), SUM(first_order_value)), 3)      AS ltv_to_first_order
  FROM base
  GROUP BY payment_segment
),

overall AS (
  SELECT
    'all'                                                            AS payment_segment,
    COUNT(*)                                                         AS customers,
    ROUND(AVG(first_order_value), 2)                                 AS avg_first_order_value,
    ROUND(AVG(ltv_12m), 2)                                           AS ltv_12m,
    ROUND(COUNTIF(days_to_2nd_order <= 365) / COUNT(*) * 100, 2)     AS repeat_rate_12m_pct,
    ROUND(SAFE_DIVIDE(SUM(ltv_12m), SUM(first_order_value)), 3)      AS ltv_to_first_order
  FROM base
)

SELECT * FROM by_segment
UNION ALL
SELECT * FROM overall;
