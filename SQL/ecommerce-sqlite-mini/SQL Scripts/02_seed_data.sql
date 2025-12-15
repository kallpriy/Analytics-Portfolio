--02_seed_data — Generating reproducible synthetic data, This script creates ~150 customers, 40 products, ~1200 orders (2024‑01‑01 to 2024‑12‑31), items per order, payments, shipments, and ~5–8% returns. It uses SQLite’s random() and recursive CTEs.

PRAGMA foreign_keys = ON; --turns on foreign key enforcement

-- 1) Customers
-- first we will create a temporary recursive table that generates 1 to 150
-- then we use those numbers to automatically insert into 150 customers which is a data generation automation query.

WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 150
) 
INSERT INTO customers (customer_id, full_name, signup_date, city, state, age, gender) 
SELECT
  n AS customer_id,
  'Customer ' || n AS full_name,
  date('2023-01-01', printf('+%d days', abs(random()) % 365)) AS signup_date,
  CASE abs(random()) % 6
    WHEN 0 THEN 'Chennai'
    WHEN 1 THEN 'Bengaluru'
    WHEN 2 THEN 'Hyderabad'
    WHEN 3 THEN 'Mumbai'
    WHEN 4 THEN 'Delhi'
    ELSE 'Pune'
  END AS city,
  CASE abs(random()) % 6
    WHEN 0 THEN 'Tamil Nadu'
    WHEN 1 THEN 'Karnataka'
    WHEN 2 THEN 'Telangana'
    WHEN 3 THEN 'Maharashtra'
    WHEN 4 THEN 'Delhi'
    ELSE 'Maharashtra'
  END AS state,
  20 + (abs(random()) % 35) AS age,
  CASE abs(random()) % 3 WHEN 0 THEN 'F' WHEN 1 THEN 'M' ELSE 'O' END AS gender
  
FROM seq;

-- 2) Products (40 items across 6 categories)
INSERT INTO products (product_id, product_name, category, price, cost)
SELECT
  p,
  CASE (p-1) / 10
    WHEN 0 THEN 'Wireless Earbuds ' || p
    WHEN 1 THEN 'Fitness Watch ' || p
    WHEN 2 THEN 'Phone Case ' || p
    WHEN 3 THEN 'Laptop Sleeve ' || p
  END AS product_name,
  CASE (p-1) / 10
    WHEN 0 THEN 'Audio'
    WHEN 1 THEN 'Wearables'
    WHEN 2 THEN 'Accessories'
    WHEN 3 THEN 'Bags'
  END AS category,
  CASE (p-1) / 10
    WHEN 0 THEN (1999 + (abs(random()) % 2000))*1.0
    WHEN 1 THEN (2999 + (abs(random()) % 3000))*1.0
    WHEN 2 THEN (399 + (abs(random()) % 600))*1.0
    WHEN 3 THEN (799 + (abs(random()) % 1200))*1.0
  END AS price,
  -- cost at 55–75% of price
  ROUND((CASE (p-1) / 10
    WHEN 0 THEN (1999 + (abs(random()) % 2000))*1.0
    WHEN 1 THEN (2999 + (abs(random()) % 3000))*1.0
    WHEN 2 THEN (399 + (abs(random()) % 600))*1.0
    WHEN 3 THEN (799 + (abs(random()) % 1200))*1.0
  END) * (0.55 + (abs(random()) % 20)/100.0), 2) AS cost
FROM (WITH RECURSIVE pseq(p) AS (SELECT 1 UNION ALL SELECT p+1 FROM pseq WHERE p < 40) SELECT p FROM pseq);

-- 3) Orders (~1200 in 2024)
WITH RECURSIVE seq(n) AS (
  SELECT 1 UNION ALL SELECT n+1 FROM seq WHERE n < 1200
)
INSERT INTO orders (order_id, customer_id, order_date, status, channel)
SELECT
  n AS order_id,
  1 + (abs(random()) % 150) AS customer_id,
  date('2024-01-01', printf('+%d days', abs(random()) % 366)) AS order_date,
  CASE abs(random()) % 10
    WHEN 0 THEN 'CANCELLED'  -- ~10%
    WHEN 1 THEN 'CANCELLED'
    WHEN 2 THEN 'PLACED'     -- some placed (later completed via payment success)
    ELSE 'COMPLETED'         -- majority completed
  END AS status,
  CASE abs(random()) % 3 WHEN 0 THEN 'APP' WHEN 1 THEN 'WEB' ELSE 'MARKETPLACE' 
  END AS channel  
  
FROM seq;

-- Normalize: For 'PLACED', convert a portion to COMPLETED to simulate fulfillment
UPDATE orders
SET status = CASE WHEN abs(random()) % 100 < 70 THEN 'COMPLETED' ELSE 'CANCELLED' END
WHERE status = 'PLACED';

-- 4) Order items: 1–3 items per order, random products
WITH RECURSIVE
  orders_list AS (SELECT order_id FROM orders),
  k(n) AS (SELECT 1 UNION ALL SELECT n+1 FROM k WHERE n < 3)
INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price, discount)
SELECT
  ROW_NUMBER() OVER () AS order_item_id,
  o.order_id,
  1 + (abs(random()) % 40) AS product_id,
  1 + (abs(random()) % 3) AS quantity,
  p.price AS unit_price,
  ROUND(p.price * (CASE WHEN abs(random()) % 100 < 20 THEN (abs(random()) % 25)/100.0 ELSE 0 END), 2) AS discount
FROM orders_list o
JOIN k ON 1=1
JOIN products p ON p.product_id = 1 + (abs(random()) % 40)
WHERE abs(random()) % 100 < 70; -- ~70% of 3 slots filled → ~2 items/order on avg

-- Ensure cancelled orders have no accidental items (rare edge after randomness)
DELETE FROM order_items
WHERE order_id IN (SELECT order_id FROM orders WHERE status='CANCELLED')
  AND abs(random()) % 100 < 60; -- most cancelled orders lose items

-- 5) Payments: one per order (SUCCESS for completed, often FAILURE for cancelled)
WITH order_totals AS (
  SELECT
    oi.order_id,
    ROUND(SUM((oi.unit_price * oi.quantity) - oi.discount), 2) AS gross_amount
  FROM order_items oi
  GROUP BY oi.order_id
)
INSERT INTO payments (payment_id, order_id, payment_method, amount, status, payment_date)
SELECT
  o.order_id AS payment_id,
  o.order_id,
  CASE abs(random()) % 4 WHEN 0 THEN 'UPI' WHEN 1 THEN 'CARD' WHEN 2 THEN 'COD' ELSE 'NBANK' END AS payment_method,
  COALESCE(ot.gross_amount, 0) AS amount,
  CASE
    WHEN o.status='COMPLETED' THEN 'SUCCESS'
    WHEN o.status='CANCELLED' THEN (CASE WHEN abs(random()) % 100 < 80 THEN 'FAILURE' ELSE 'SUCCESS' END)
    ELSE 'FAILURE'
  END AS status,
  date(o.order_date, printf('+%d days', abs(random()) % 2)) AS payment_date
FROM orders o
LEFT JOIN order_totals ot ON ot.order_id = o.order_id;

-- 6) Shipments: for completed orders
INSERT INTO shipments (shipment_id, order_id, shipped_date, delivered_date, carrier, sla_days)
SELECT
  o.order_id AS shipment_id,
  o.order_id,
  date(o.order_date, printf('+%d days', 1 + (abs(random()) % 2))) AS shipped_date,
  date(o.order_date, printf('+%d days', 2 + (abs(random()) % 7))) AS delivered_date,
  CASE abs(random()) % 3 WHEN 0 THEN 'Bluedart' WHEN 1 THEN 'Delhivery' ELSE 'Ecom' END AS carrier,
  5 AS sla_days
FROM orders o
WHERE o.status='COMPLETED';

-- Introduce some delayed deliveries beyond SLA for realism
UPDATE shipments
SET delivered_date = date(shipped_date, printf('+%d days', sla_days + 1 + (abs(random()) % 3)))
WHERE abs(random()) % 100 < 18; -- ~18% late

-- 7) Returns: ~6% of line items from delivered orders
WITH delivered_orders AS (
  SELECT s.order_id
  FROM shipments s
  WHERE s.delivered_date IS NOT NULL
),
eligible_items AS (
  SELECT oi.order_item_id, oi.order_id
  FROM order_items oi
  WHERE oi.order_id IN (SELECT order_id FROM delivered_orders)
),
sampled AS (
  SELECT order_item_id, order_id
  FROM eligible_items
  WHERE abs(random()) % 100 < 6
)
INSERT INTO returns (return_id, order_item_id, return_date, reason)
SELECT
  row_number() OVER () AS return_id,
  s.order_item_id,
  date((SELECT delivered_date FROM shipments WHERE order_id = s.order_id),
       printf('+%d days', 1 + (abs(random()) % 20))) AS return_date,
  CASE abs(random()) % 4
    WHEN 0 THEN 'Damaged'
    WHEN 1 THEN 'Wrong Size'
    WHEN 2 THEN 'Not as described'
    ELSE 'No longer needed'
  END AS reason
FROM sampled s;