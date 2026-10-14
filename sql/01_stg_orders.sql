-- 01 · Staging: one row per valid order.
-- Grain: order_id.
-- * Swaps the per-order customer_id for customer_unique_id (the real person key).
-- * Order value = sum of all payments (product + freight), i.e. GMV.
-- * customer_state = state (UF) of the delivery address on this order.
-- * Main payment type = the method that paid the largest share of the order.
-- * Drops canceled/unavailable orders and the sparse tail after 2018-08 (analysis cutoff).

CREATE OR REPLACE TABLE olist_mart.stg_orders AS
WITH payment_totals AS (
  SELECT
    order_id,
    SUM(payment_value)        AS order_value,
    MAX(payment_installments) AS installments
  FROM olist_raw.order_payments
  GROUP BY order_id
),

payment_ranked AS (
  SELECT
    order_id,
    payment_type,
    ROW_NUMBER() OVER (
      PARTITION BY order_id
      ORDER BY payment_value DESC, payment_sequential
    ) AS payment_rank
  FROM olist_raw.order_payments
)

SELECT
  o.order_id,
  c.customer_unique_id                                 AS customer_id,
  c.customer_state,
  o.order_status,
  o.order_purchase_timestamp                           AS purchased_at,
  DATE(o.order_purchase_timestamp)                     AS purchase_date,
  CAST(DATE_TRUNC(DATE(o.order_purchase_timestamp), MONTH) AS DATE) AS order_month,
  pt.order_value,
  pr.payment_type                                      AS main_payment_type,
  pt.installments
FROM olist_raw.orders AS o
JOIN olist_raw.customers AS c
  ON c.customer_id = o.customer_id
JOIN payment_totals AS pt
  ON pt.order_id = o.order_id
JOIN payment_ranked AS pr
  ON pr.order_id = o.order_id
 AND pr.payment_rank = 1
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND o.order_purchase_timestamp < TIMESTAMP '2018-09-01';
