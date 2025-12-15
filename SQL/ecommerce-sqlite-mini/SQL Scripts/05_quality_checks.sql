--05_quality_checks — Data sanity & QA

-- 1) Orphan checks
SELECT 'orphan_order_items' AS check_name, COUNT(*) AS cnt
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

SELECT 'orphan_order_items_products' AS check_name, COUNT(*) AS cnt
FROM order_items oi
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE p.product_id IS NULL;

-- 2) Payment coverage (should be 1 per order)
SELECT 'orders_without_payment' AS check_name, COUNT(*) AS cnt
FROM orders o
LEFT JOIN payments p ON p.order_id = o.order_id
WHERE p.order_id IS NULL;

SELECT 'duplicate_payments' AS check_name, COUNT(*) AS cnt
FROM payments
GROUP BY order_id
HAVING COUNT(*) > 1;

-- 3) Shipment only for completed orders
SELECT 'shipments_not_completed' AS check_name, COUNT(*) AS cnt
FROM shipments s
JOIN orders o ON o.order_id = s.order_id
WHERE o.status <> 'COMPLETED';

-- 4) Amount integrity (payment amount ≈ order total)
WITH totals AS (
  SELECT order_id, ROUND(SUM((unit_price * quantity) - discount),2) AS expected_amount
  FROM order_items
  GROUP BY order_id
)
SELECT 'payment_mismatch' AS check_name, COUNT(*) AS cnt
FROM payments p
LEFT JOIN totals t ON t.order_id = p.order_id
WHERE ROUND(COALESCE(p.amount,0),2) <> ROUND(COALESCE(t.expected_amount,0),2);

-- 5) Returns only from delivered orders
SELECT 'returns_without_delivery' AS check_name, COUNT(*) AS cnt
FROM returns r
LEFT JOIN order_items oi ON oi.order_item_id = r.order_item_id
LEFT JOIN shipments s ON s.order_id = oi.order_id
WHERE s.delivered_date IS NULL;
