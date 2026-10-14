-- 99 · Data quality checks. Every row must return failures = 0.

SELECT 'stg_orders.order_id is unique' AS check_name, COUNT(*) AS failures
FROM (SELECT order_id FROM olist_mart.stg_orders GROUP BY order_id HAVING COUNT(*) > 1)

UNION ALL
SELECT 'stg_orders has no null keys', COUNT(*)
FROM olist_mart.stg_orders
WHERE order_id IS NULL OR customer_id IS NULL OR purchased_at IS NULL

UNION ALL
SELECT 'order_value is not negative', COUNT(*)
FROM olist_mart.stg_orders
WHERE order_value < 0

UNION ALL
SELECT 'month_number is not negative', COUNT(*)
FROM olist_mart.customer_orders
WHERE month_number < 0

UNION ALL
SELECT 'month 0 retention is 100%', COUNT(*)
FROM olist_mart.cohort_retention
WHERE month_number = 0 AND retention_pct <> 100

UNION ALL
SELECT 'retention never exceeds 100%', COUNT(*)
FROM olist_mart.cohort_retention
WHERE retention_pct > 100

UNION ALL
SELECT 'customers.customer_id is unique', COUNT(*)
FROM (SELECT customer_id FROM olist_mart.customers GROUP BY customer_id HAVING COUNT(*) > 1)

UNION ALL
SELECT 'cohort sizes match customer table', COUNT(*)
FROM (
  SELECT cohort_month, MAX(cohort_customers) AS n
  FROM olist_mart.cohort_retention
  GROUP BY cohort_month
) AS r
JOIN (
  SELECT cohort_month, COUNT(*) AS n
  FROM olist_mart.customers
  GROUP BY cohort_month
) AS c
  ON c.cohort_month = r.cohort_month
WHERE r.n <> c.n

UNION ALL
SELECT 'ltv is non-decreasing over months', COUNT(*)
FROM (
  SELECT ltv, LAG(ltv) OVER (PARTITION BY cohort_month ORDER BY month_number) AS prev_ltv
  FROM olist_mart.cohort_ltv
)
WHERE ltv < prev_ltv

UNION ALL
SELECT 'segment customers add up to total', ABS(
  (SELECT SUM(customers) FROM olist_mart.segment_ltv WHERE payment_segment <> 'all')
  - (SELECT customers FROM olist_mart.segment_ltv WHERE payment_segment = 'all')
)

UNION ALL
SELECT 'f_customers reconciles with customers', COUNT(*)
FROM (
  SELECT COUNT(*) AS n, ROUND(SUM(ltv_12m), 0) AS ltv FROM olist_mart.customers
) AS c
CROSS JOIN (
  SELECT SUM(customers) AS n, ROUND(SUM(ltv_12m_gmv), 0) AS ltv FROM olist_mart.f_customers
) AS f
WHERE c.n <> f.n OR c.ltv <> f.ltv

UNION ALL
SELECT 'f_cohort_month reconciles with cohort_retention', COUNT(*)
FROM (
  SELECT cohort_month, month_number,
         SUM(cohort_customers) AS cohort_customers, SUM(active_customers) AS active_customers
  FROM olist_mart.f_cohort_month
  GROUP BY cohort_month, month_number
) AS f
FULL OUTER JOIN olist_mart.cohort_retention AS r
  ON r.cohort_month = f.cohort_month
 AND r.month_number = f.month_number
WHERE r.cohort_month IS NULL OR f.cohort_month IS NULL
   OR r.cohort_customers <> f.cohort_customers
   OR r.active_customers <> f.active_customers

UNION ALL
SELECT 'f_repurchase reconciles with repurchase_curve', COUNT(*)
FROM (
  SELECT days_window, SUM(repeaters_within) AS n
  FROM olist_mart.f_repurchase
  GROUP BY days_window
) AS f
JOIN olist_mart.repurchase_curve AS r
  ON r.days_window = f.days_window
WHERE r.repeaters_within <> f.n;
