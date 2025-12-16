CREATE TABLE saas.customers (
    customer_id SERIAL PRIMARY KEY,
    customer_name TEXT,
    signup_date DATE,
    country TEXT,
    industry TEXT
);
-------
CREATE TABLE saas.subscription_plans (
    plan_id SERIAL PRIMARY KEY,
    plan_name TEXT,
    monthly_price NUMERIC(10,2),
    billing_cycle TEXT  -- monthly / yearly
);
-------
CREATE TABLE saas.subscriptions (
    subscription_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES saas.customers(customer_id),
    plan_id INT REFERENCES saas.subscription_plans(plan_id),
    start_date DATE,
    end_date DATE,
    status TEXT -- active / cancelled
);
-------
CREATE TABLE saas.invoices (
    invoice_id SERIAL PRIMARY KEY,
    subscription_id INT REFERENCES saas.subscriptions(subscription_id),
    invoice_date DATE,
    amount NUMERIC(10,2)
);
-------
CREATE TABLE saas.payments (
    payment_id SERIAL PRIMARY KEY,
    invoice_id INT REFERENCES saas.invoices(invoice_id),
    payment_date DATE,
    payment_status TEXT
);
--------
CREATE TABLE saas.product_usage_events (
    event_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES saas.customers(customer_id),
    event_date DATE,
    event_type TEXT
);
--------
SELECT
    tc.table_name,kcu.column_name, ccu.table_name AS references_table,ccu.column_name AS references_column
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
  ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
  ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'saas';
  --------
  