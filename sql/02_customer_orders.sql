-- 02 · Customer orders: each order tagged with the customer's cohort and history.
-- Grain: order_id.
-- * cohort_month   = month of the customer's first order (acquisition cohort).
-- * month_number   = months since the cohort month (0 = acquisition month).
-- * is_repeat      = order placed on a later day than the first order.
--                    Same-day extra orders are split carts, not repurchases.
-- * payment_segment = how the customer paid the FIRST order (fintech hook).
-- Cohorts start in 2017-01; the 2016 months are too sparse to analyse.

CREATE OR REPLACE TABLE olist_mart.customer_orders AS
WITH sequenced AS (
  SELECT
    *,
    ROW_NUMBER() OVER (
      PARTITION BY customer_id
      ORDER BY purchased_at, order_id
    )                                                   AS order_seq,
    MIN(order_month)   OVER (PARTITION BY customer_id) AS cohort_month,
    MIN(purchase_date) OVER (PARTITION BY customer_id) AS first_purchase_date
  FROM olist_mart.stg_orders
),

first_order AS (
  SELECT
    customer_id,
    main_payment_type AS first_payment_type,
    installments      AS first_installments
  FROM sequenced
  WHERE order_seq = 1
)

SELECT
  s.order_id,
  s.customer_id,
  s.purchased_at,
  s.purchase_date,
  s.order_month,
  s.order_value,
  s.order_seq,
  s.cohort_month,
  s.first_purchase_date,
  DATE_DIFF(s.order_month, s.cohort_month, MONTH)          AS month_number,
  DATE_DIFF(s.purchase_date, s.first_purchase_date, DAY)   AS days_since_first_order,
  s.purchase_date > s.first_purchase_date                  AS is_repeat,
  f.first_payment_type,
  f.first_installments,
  CASE
    WHEN f.first_payment_type <> 'credit_card' THEN f.first_payment_type
    WHEN f.first_installments <= 1 THEN 'credit_card 1x'
    WHEN f.first_installments <= 3 THEN 'credit_card 2-3x'
    WHEN f.first_installments <= 6 THEN 'credit_card 4-6x'
    ELSE 'credit_card 7x+'
  END                                                      AS payment_segment
FROM sequenced AS s
JOIN first_order AS f
  ON f.customer_id = s.customer_id
WHERE s.cohort_month >= DATE '2017-01-01';
