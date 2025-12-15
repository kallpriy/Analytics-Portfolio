--04_analytics — Core business questions (CTEs, windows)

-- 1) Company KPIs: Revenue & Margin by Month
WITH monthly AS (
  SELECT
    strftime('%Y-%m', order_date) AS ym,
    SUM(CASE WHEN status='COMPLETED' THEN gross_revenue ELSE 0 END) AS gross_rev,
    SUM(CASE WHEN status='COMPLETED' THEN gross_margin  ELSE 0 END) AS gross_margin,
    SUM(CASE WHEN status='COMPLETED' THEN net_revenue   ELSE 0 END) AS net_rev,
    SUM(CASE WHEN status='COMPLETED' THEN net_margin    ELSE 0 END) AS net_margin
  FROM vw_order_totals
  GROUP BY ym
)
SELECT ym,
       ROUND(gross_rev,2)  AS gross_revenue,
       ROUND(net_rev,2)    AS net_revenue,
       ROUND(gross_margin,2) AS gross_margin,
       ROUND(net_margin,2)   AS net_margin
FROM monthly
ORDER BY ym;

-- 2) Top 10 Products by Net Revenue (with Pareto flag)
WITH prod AS (
  SELECT
    p.product_id,
    p.product_name,
    p.category,
    ROUND(SUM(ot.net_revenue),2) AS net_rev
  FROM vw_order_totals ot
  JOIN order_items oi ON oi.order_id = ot.order_id
  JOIN products p ON p.product_id = oi.product_id
  WHERE ot.status='COMPLETED'
  GROUP BY p.product_id, p.product_name, p.category
),
ranked AS (
  SELECT *,
         RANK() OVER (ORDER BY net_rev DESC) AS rnk,
         ROUND(SUM(net_rev) OVER (ORDER BY net_rev DESC)
              / SUM(net_rev) OVER (), 4) AS cum_share
  FROM prod
)
SELECT product_id, product_name, category, net_rev,
       CASE WHEN cum_share <= 0.8 THEN 'A'
            WHEN cum_share <= 0.95 THEN 'B'
            ELSE 'C' END AS abc_class
FROM ranked
ORDER BY net_rev DESC
LIMIT 10;

-- 3) Payment success rate by method
SELECT
  payment_method,
  COUNT(*) AS attempts,
  SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) AS successes,
  ROUND(100.0 * SUM(CASE WHEN status='SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct,
  ROUND(AVG(amount),2) AS avg_amount
FROM payments
GROUP BY payment_method
ORDER BY success_rate_pct DESC;

-- 4) On-time delivery rate by carrier
SELECT
  carrier,
  COUNT(*) AS delivered,
  SUM(CASE WHEN sla_status='ON_TIME' THEN 1 ELSE 0 END) AS on_time,
  ROUND(100.0 * SUM(CASE WHEN sla_status='ON_TIME' THEN 1 ELSE 0 END) / COUNT(*), 2) AS on_time_rate_pct
FROM vw_delivery_sla d
JOIN shipments s ON s.order_id = d.order_id
GROUP BY carrier
ORDER BY on_time_rate_pct DESC;

-- 5) Return rate by category
WITH lines AS (
  SELECT
    p.category,
    COUNT(*) AS line_count
  FROM order_items oi
  JOIN products p ON p.product_id = oi.product_id
  JOIN orders o ON o.order_id = oi.order_id
  WHERE o.status='COMPLETED'
  GROUP BY p.category
),
ret AS (
  SELECT
    p.category,
    COUNT(*) AS returned_lines
  FROM returns r
  JOIN order_items oi ON oi.order_item_id = r.order_item_id
  JOIN products p ON p.product_id = oi.product_id
  GROUP BY p.category
)
SELECT
  l.category,
  l.line_count,
  COALESCE(r.returned_lines,0) AS returned_lines,
  ROUND(100.0 * COALESCE(r.returned_lines,0) / l.line_count, 2) AS return_rate_pct
FROM lines l
LEFT JOIN ret r ON r.category = l.category
ORDER BY return_rate_pct DESC;

-- 6) RFM segmentation (quartiles via percent_rank buckets)
WITH completed_orders AS (
  SELECT customer_id, order_id, order_date
  FROM orders
  WHERE status='COMPLETED'
),
monetary AS (
  SELECT
    ot.customer_id,
    SUM(ot.net_revenue) AS m
  FROM vw_order_totals ot
  WHERE ot.status='COMPLETED'
  GROUP BY ot.customer_id
),
recency AS (
  SELECT
    c.customer_id,
    -- recency in days since last order relative to max date in data
    CAST(julianday((SELECT MAX(order_date) FROM orders)) - julianday(MAX(order_date)) AS INTEGER) AS r
  FROM completed_orders c
  GROUP BY c.customer_id
),
frequency AS (
  SELECT customer_id, COUNT(*) AS f
  FROM completed_orders
  GROUP BY customer_id
),
rfm_raw AS (
  SELECT
    c.customer_id,
    COALESCE(r.r, 9999) AS recency_days,
    COALESCE(f.f, 0)    AS frequency_cnt,
    ROUND(COALESCE(m.m, 0), 2) AS monetary_value
  FROM customers c
  LEFT JOIN recency r ON r.customer_id = c.customer_id
  LEFT JOIN frequency f ON f.customer_id = c.customer_id
  LEFT JOIN monetary m ON m.customer_id = c.customer_id
),
scored AS (
  SELECT *,
    -- lower recency_days is better → invert bucket
    CASE
      WHEN percent_rank() OVER (ORDER BY recency_days ASC) <= 0.25 THEN 4
      WHEN percent_rank() OVER (ORDER BY recency_days ASC) <= 0.5  THEN 3
      WHEN percent_rank() OVER (ORDER BY recency_days ASC) <= 0.75 THEN 2
      ELSE 1
    END AS r_score,
    CASE
      WHEN percent_rank() OVER (ORDER BY frequency_cnt ASC) <= 0.25 THEN 1
      WHEN percent_rank() OVER (ORDER BY frequency_cnt ASC) <= 0.5  THEN 2
      WHEN percent_rank() OVER (ORDER BY frequency_cnt ASC) <= 0.75 THEN 3
      ELSE 4
    END AS f_score,
    CASE
      WHEN percent_rank() OVER (ORDER BY monetary_value ASC) <= 0.25 THEN 1
      WHEN percent_rank() OVER (ORDER BY monetary_value ASC) <= 0.5  THEN 2
      WHEN percent_rank() OVER (ORDER BY monetary_value ASC) <= 0.75 THEN 3
      ELSE 4
    END AS m_score
  FROM rfm_raw
)
SELECT
  customer_id,
  recency_days, frequency_cnt, monetary_value,
  r_score, f_score, m_score,
  (r_score || f_score || m_score) AS rfm_code
FROM scored
ORDER BY monetary_value DESC
LIMIT 50;

-- 7) Cohort analysis: retention table (cohort month vs months since)
WITH firsts AS (
  SELECT customer_id, strftime('%Y-%m', MIN(order_date)) AS cohort_ym
  FROM orders
  WHERE status='COMPLETED'
  GROUP BY customer_id
),
activity AS (
  SELECT
    o.customer_id,
    strftime('%Y-%m', o.order_date) AS ym
  FROM orders o
  WHERE o.status='COMPLETED'
),
joined AS (
  SELECT a.customer_id, f.cohort_ym, a.ym,
         (CAST(strftime('%Y', a.ym || '-01') AS INT) - CAST(strftime('%Y', f.cohort_ym || '-01') AS INT)) * 12 +
         (CAST(strftime('%m', a.ym || '-01') AS INT) - CAST(strftime('%m', f.cohort_ym || '-01') AS INT)) AS months_since
  FROM activity a
  JOIN firsts f ON f.customer_id = a.customer_id
)
SELECT
  cohort_ym,
  SUM(CASE WHEN months_since=0 THEN 1 ELSE 0 END) AS m0,
  SUM(CASE WHEN months_since=1 THEN 1 ELSE 0 END) AS m1,
  SUM(CASE WHEN months_since=2 THEN 1 ELSE 0 END) AS m2,
  SUM(CASE WHEN months_since=3 THEN 1 ELSE 0 END) AS m3,
  SUM(CASE WHEN months_since=4 THEN 1 ELSE 0 END) AS m4,
  SUM(CASE WHEN months_since=5 THEN 1 ELSE 0 END) AS m5,
  SUM(CASE WHEN months_since=6 THEN 1 ELSE 0 END) AS m6
FROM joined
GROUP BY cohort_ym
ORDER BY cohort_ym;
