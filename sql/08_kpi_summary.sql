-- 08 · Headline KPIs for the dashboard scorecards.
-- Grain: one row.
-- cac_ceiling = average 12-month LTV (GMV basis) of cohorts with a full window.

CREATE OR REPLACE TABLE olist_mart.kpi_summary AS
SELECT
  (SELECT COUNT(*) FROM olist_mart.stg_orders)                                    AS orders,
  COUNT(*)                                                                        AS customers,
  ROUND(COUNTIF(is_repeat_customer) / COUNT(*) * 100, 2)                          AS repeat_customer_pct,
  ROUND(AVG(first_order_value), 2)                                                AS avg_first_order_value,
  ROUND(AVG(IF(has_full_12m, ltv_12m, NULL)), 2)                                  AS ltv_12m,
  ROUND(AVG(IF(has_full_12m, ltv_12m, NULL)), 2)                                  AS cac_ceiling,
  ROUND(SAFE_DIVIDE(SUM(IF(has_full_12m, ltv_12m, 0)),
                    SUM(IF(has_full_12m, first_order_value, 0))), 3)              AS ltv_to_first_order,
  ROUND(SAFE_DIVIDE(COUNTIF(is_churn_eligible AND is_churned),
                    COUNTIF(is_churn_eligible)) * 100, 2)                         AS churn_180d_pct,
  APPROX_QUANTILES(days_to_2nd_order, 2)[OFFSET(1)]                               AS median_days_to_2nd_order
FROM olist_mart.customers;
