---1) Monthly Recurring Revenue (MRR):

SELECT
  DATE_TRUNC('month', invoice_date) AS month,
  SUM(amount) AS mrr
FROM saas.invoices
GROUP BY 1
ORDER BY 1;


---2) New vs Expansion vs Churned Revenue

WITH monthly_revenue AS (
    SELECT
        s.customer_id,
        DATE_TRUNC('month', i.invoice_date) AS month,
        SUM(i.amount) AS revenue
    FROM saas.invoices i
    JOIN saas.subscriptions s
        ON i.subscription_id = s.subscription_id
    GROUP BY 1,2
),
lagged AS (
    SELECT
        customer_id,
        month,
        revenue,
        LAG(revenue) OVER (
            PARTITION BY customer_id
            ORDER BY month
        ) AS prev_revenue
    FROM monthly_revenue
)
SELECT
    month,
    SUM(CASE WHEN prev_revenue IS NULL THEN revenue ELSE 0 END) AS new_revenue,
    SUM(CASE WHEN revenue > prev_revenue THEN revenue - prev_revenue ELSE 0 END) AS expansion_revenue,
    SUM(CASE WHEN revenue < prev_revenue THEN prev_revenue - revenue ELSE 0 END) AS contraction_revenue
FROM lagged
GROUP BY month
ORDER BY month;



--- 3) Churn Rate : Churned customers per month
SELECT
  DATE_TRUNC('month', end_date) AS churn_month,
  COUNT(DISTINCT customer_id) AS churned_customers
FROM saas.subscriptions
WHERE status = 'cancelled'
GROUP BY 1
ORDER BY 1;


--- 4) Cohort Analysis (SIGNUP COHORT)

WITH cohorts AS (
  SELECT
    customer_id,
    DATE_TRUNC('month', signup_date) AS cohort_month
  FROM saas.customers
),
activity AS (
  SELECT
    c.cohort_month,
    DATE_TRUNC('month', i.invoice_date) AS revenue_month,
    COUNT(DISTINCT s.customer_id) AS active_customers
  FROM saas.invoices i
  JOIN saas.subscriptions s
    ON i.subscription_id = s.subscription_id
  JOIN cohorts c
    ON s.customer_id = c.customer_id
  GROUP BY 1,2
)
SELECT
  cohort_month,
  revenue_month,
  active_customers,
  active_customers * 100.0 /
    FIRST_VALUE(active_customers)
    OVER (PARTITION BY cohort_month ORDER BY revenue_month) AS retention_pct
FROM activity
ORDER BY cohort_month, revenue_month;



--- 5) LTV (Simplified)

SELECT
    c.customer_id,
    SUM(i.amount) AS lifetime_value
FROM saas.invoices i
JOIN saas.subscriptions s ON i.subscription_id = s.subscription_id
JOIN saas.customers c ON s.customer_id = c.customer_id
GROUP BY 1;

--- 7) Usage vs Churn Correlation

SELECT
  s.status,
  COUNT(DISTINCT s.customer_id) AS customers,
  COUNT(u.event_id) * 1.0 / COUNT(DISTINCT s.customer_id) AS avg_events_per_customer
FROM saas.subscriptions s
LEFT JOIN saas.product_usage_events u
  ON s.customer_id = u.customer_id
GROUP BY s.status;