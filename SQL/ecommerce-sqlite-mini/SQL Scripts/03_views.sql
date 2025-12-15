--03_views — Helpful analytical views

PRAGMA foreign_keys = ON;

-- Order-level totals (amount & margin)
CREATE VIEW IF NOT EXISTS vw_order_totals AS
WITH line AS (
  SELECT
    oi.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price,
    oi.discount,
    (oi.unit_price - p.cost) * oi.quantity - oi.discount AS line_margin,
    (oi.unit_price * oi.quantity) - oi.discount AS line_revenue
  FROM order_items oi
  JOIN products p ON p.product_id = oi.product_id
),
returned AS (
  SELECT
    oi.order_id,
    SUM((oi.unit_price * oi.quantity) - oi.discount) AS returned_revenue,
    SUM((oi.unit_price - p.cost) * oi.quantity - oi.discount) AS returned_margin
  FROM returns r
  JOIN order_items oi ON oi.order_item_id = r.order_item_id
  JOIN products p ON p.product_id = oi.product_id
  GROUP BY oi.order_id
)
SELECT
  o.order_id,
  o.customer_id,
  o.order_date,
  o.status,
  o.channel,
  ROUND(COALESCE(SUM(l.line_revenue),0),2)     AS gross_revenue,
  ROUND(COALESCE(SUM(l.line_margin),0),2)      AS gross_margin,
  ROUND(COALESCE(r.returned_revenue,0),2)      AS returned_revenue,
  ROUND(COALESCE(r.returned_margin,0),2)       AS returned_margin,
  ROUND(COALESCE(SUM(l.line_revenue),0) - COALESCE(r.returned_revenue,0),2) AS net_revenue,
  ROUND(COALESCE(SUM(l.line_margin),0) - COALESCE(r.returned_margin,0),2)   AS net_margin
FROM orders o
LEFT JOIN line l ON l.order_id = o.order_id
LEFT JOIN returned r ON r.order_id = o.order_id
GROUP BY o.order_id;

-- Customer first order date (cohort)
CREATE VIEW IF NOT EXISTS vw_customer_first_order AS
SELECT
  c.customer_id,
  MIN(o.order_date) AS first_order_date,
  strftime('%Y-%m', MIN(o.order_date)) AS cohort_ym
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.customer_id AND o.status='COMPLETED'
GROUP BY c.customer_id;

-- Order + shipment SLA status
CREATE VIEW vw_delivery_sla AS
SELECT
  s.order_id,
  s.shipped_date,
  s.delivered_date,
  s.sla_days,
  CASE
    WHEN s.delivered_date IS NULL OR s.shipped_date IS NULL THEN 'UNKNOWN'
    WHEN julianday(s.delivered_date) - julianday(s.shipped_date) <= s.sla_days THEN 'ON_TIME'
    ELSE 'LATE'
  END AS sla_status
FROM shipments s;