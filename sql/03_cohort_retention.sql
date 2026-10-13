-- 03 · Retention matrix: share of each cohort that buys again in month N.
-- Grain: cohort_month x month_number (only cells observable before the cutoff).
-- Full grid via GENERATE_ARRAY so months with zero buyers show 0, not a gap.

CREATE OR REPLACE TABLE olist_mart.cohort_retention AS
WITH cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_customers
  FROM olist_mart.customer_orders
  GROUP BY cohort_month
),

grid AS (
  SELECT
    cs.cohort_month,
    cs.cohort_customers,
    month_number
  FROM cohort_size AS cs
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 19)) AS month_number
  WHERE DATE_ADD(cs.cohort_month, INTERVAL month_number MONTH) <= DATE '2018-08-01'
),

activity AS (
  SELECT
    cohort_month,
    month_number,
    -- month 0 counts every buyer; later months count only real repurchases
    COUNT(DISTINCT IF(month_number = 0 OR is_repeat, customer_id, NULL)) AS active_customers,
    SUM(order_value)                                                     AS revenue
  FROM olist_mart.customer_orders
  GROUP BY cohort_month, month_number
)

SELECT
  g.cohort_month,
  g.month_number,
  g.cohort_customers,
  COALESCE(a.active_customers, 0)                                        AS active_customers,
  ROUND(SAFE_DIVIDE(COALESCE(a.active_customers, 0), g.cohort_customers) * 100, 2) AS retention_pct,
  ROUND(COALESCE(a.revenue, 0), 2)                                       AS revenue
FROM grid AS g
LEFT JOIN activity AS a
  ON a.cohort_month = g.cohort_month
 AND a.month_number = g.month_number;
