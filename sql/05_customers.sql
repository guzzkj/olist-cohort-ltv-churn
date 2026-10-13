-- 05 · Customer-level summary: LTV-12, repurchase timing and inactivity churn.
-- Grain: customer_id.
-- * ltv_12m           = GMV in the first 12 months (month_number 0..11).
-- * days_to_2nd_order = days from first purchase to the first repeat purchase.
-- * is_churned        = no purchase in the last 180 days before the cutoff.
--   180 days covers most observed repurchases (see 06_repurchase_curve.sql).
--   Only customers acquired 180+ days before the cutoff are eligible.

CREATE OR REPLACE TABLE olist_mart.customers AS
WITH per_customer AS (
  SELECT
    customer_id,
    cohort_month,
    payment_segment,
    first_payment_type,
    first_installments,
    MIN(purchase_date)                                     AS first_purchase_date,
    MAX(purchase_date)                                     AS last_purchase_date,
    COUNT(DISTINCT order_id)                               AS orders,
    SUM(IF(order_seq = 1, order_value, 0))                 AS first_order_value,
    SUM(IF(month_number <= 11, order_value, 0))            AS ltv_12m,
    SUM(order_value)                                       AS total_value,
    MIN(IF(is_repeat, days_since_first_order, NULL))       AS days_to_2nd_order
  FROM olist_mart.customer_orders
  GROUP BY customer_id, cohort_month, payment_segment, first_payment_type, first_installments
)

SELECT
  *,
  days_to_2nd_order IS NOT NULL                                      AS is_repeat_customer,
  DATE_DIFF(DATE '2018-08-31', last_purchase_date, DAY)              AS days_since_last_order,
  DATE_DIFF(DATE '2018-08-31', first_purchase_date, DAY) >= 180      AS is_churn_eligible,
  DATE_DIFF(DATE '2018-08-31', last_purchase_date, DAY) >= 180       AS is_churned,
  cohort_month <= DATE '2017-09-01'                                  AS has_full_12m
FROM per_customer;
