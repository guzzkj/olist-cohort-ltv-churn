-- 09 · Dashboard fact tables: additive measures at the grain of the dashboard filters.
-- Every table shares cohort_month, payment_segment and customer_state, so one Looker Studio
-- filter control on each field filters all charts at once. Tables store counts and sums only;
-- rates are computed in Looker as SUM(numerator) / SUM(denominator), which stays correct
-- under any filter combination (averaging pre-computed percentages would not).

-- f_customers · Grain: cohort_month x payment_segment x customer_state.
-- Scorecards and segment charts. LTV-12 and 12m repurchase: filter has_full_12m = true.
CREATE OR REPLACE TABLE olist_mart.f_customers AS
SELECT
  cohort_month,
  payment_segment,
  customer_state,
  has_full_12m,
  COUNT(*)                                          AS customers,
  SUM(orders)                                       AS orders,
  COUNTIF(is_repeat_customer)                       AS repeat_customers,
  COUNTIF(days_to_2nd_order <= 365)                 AS repeat_customers_12m,
  ROUND(SUM(first_order_value), 2)                  AS first_order_gmv,
  ROUND(SUM(ltv_12m), 2)                            AS ltv_12m_gmv,
  COUNTIF(is_churn_eligible)                        AS churn_eligible_customers,
  COUNTIF(is_churn_eligible AND is_churned)         AS churned_customers
FROM olist_mart.customers
GROUP BY cohort_month, payment_segment, customer_state, has_full_12m;

-- f_cohort_month · Grain: cohort_month x payment_segment x customer_state x month_number.
-- Retention heatmap and cumulative LTV curve. Full grid (zeros included) for every slice
-- that has customers, so heatmap cells show 0 instead of a gap.
-- cumulative_revenue is a running sum per slice; running sums stay additive across slices.
CREATE OR REPLACE TABLE olist_mart.f_cohort_month AS
WITH slice_size AS (
  SELECT
    cohort_month,
    payment_segment,
    customer_state,
    COUNT(*) AS cohort_customers
  FROM olist_mart.customers
  GROUP BY cohort_month, payment_segment, customer_state
),

grid AS (
  SELECT
    s.*,
    month_number
  FROM slice_size AS s
  CROSS JOIN UNNEST(GENERATE_ARRAY(0, 19)) AS month_number
  WHERE DATE_ADD(s.cohort_month, INTERVAL month_number MONTH) <= DATE '2018-08-01'
),

activity AS (
  SELECT
    cohort_month,
    payment_segment,
    customer_state,
    month_number,
    COUNT(DISTINCT IF(month_number = 0 OR is_repeat, customer_id, NULL)) AS active_customers,
    SUM(order_value)                                                     AS revenue
  FROM olist_mart.customer_orders
  GROUP BY cohort_month, payment_segment, customer_state, month_number
)

SELECT
  g.cohort_month,
  g.payment_segment,
  g.customer_state,
  g.month_number,
  g.cohort_month <= DATE '2017-09-01'                  AS has_full_12m,
  g.cohort_customers,
  COALESCE(a.active_customers, 0)                      AS active_customers,
  ROUND(COALESCE(a.revenue, 0), 2)                     AS revenue,
  ROUND(SUM(COALESCE(a.revenue, 0)) OVER (
    PARTITION BY g.cohort_month, g.payment_segment, g.customer_state
    ORDER BY g.month_number
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ), 2)                                                AS cumulative_revenue
FROM grid AS g
LEFT JOIN activity AS a
  ON a.cohort_month = g.cohort_month
 AND a.payment_segment = g.payment_segment
 AND a.customer_state = g.customer_state
 AND a.month_number = g.month_number;

-- f_repurchase · Grain: cohort_month x payment_segment x customer_state x days_window.
-- Repurchase curve: share of second purchases within N days = SUM(repeaters_within) / SUM(repeaters).
CREATE OR REPLACE TABLE olist_mart.f_repurchase AS
SELECT
  cohort_month,
  payment_segment,
  customer_state,
  days_window,
  COUNT(*)                                          AS repeaters,
  COUNTIF(days_to_2nd_order <= days_window)         AS repeaters_within
FROM olist_mart.customers
CROSS JOIN UNNEST([30, 60, 90, 120, 180, 270, 365, 540]) AS days_window
WHERE is_repeat_customer
GROUP BY cohort_month, payment_segment, customer_state, days_window;
