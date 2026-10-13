-- 06 · Repurchase curve: how fast do repeat customers come back?
-- Grain: days_window. Share of all second purchases that happen within N days.
-- Used to pick the inactivity threshold that defines churn.

CREATE OR REPLACE TABLE olist_mart.repurchase_curve AS
WITH repeaters AS (
  SELECT days_to_2nd_order
  FROM olist_mart.customers
  WHERE is_repeat_customer
)

SELECT
  days_window,
  COUNTIF(r.days_to_2nd_order <= days_window)                                      AS repeaters_within,
  ROUND(SAFE_DIVIDE(COUNTIF(r.days_to_2nd_order <= days_window), COUNT(*)) * 100, 2) AS pct_of_repeaters
FROM repeaters AS r
CROSS JOIN UNNEST([30, 60, 90, 120, 180, 270, 365, 540]) AS days_window
GROUP BY days_window;
