--01.Revenue Breakdown View :New vs Expansion vs Contraction (monthly)

CREATE OR REPLACE VIEW saas.v_revenue_breakdown AS
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


--02. Churn view :Monthly churned customers + churn rate
DROP VIEW IF EXISTS saas.v_churn_monthly;
     CREATE VIEW saas.v_churn_monthly AS
WITH months AS (
    SELECT
        generate_series(
            DATE_TRUNC('month', MIN(start_date)),
            DATE_TRUNC('month', CURRENT_DATE),
            INTERVAL '1 month'
        ) AS month
    FROM saas.subscriptions
),
active_base AS (
    SELECT
        m.month,
        COUNT(DISTINCT s.customer_id) AS active_customers
    FROM months m
    JOIN saas.subscriptions s
      ON s.start_date < m.month
     AND (s.end_date IS NULL OR s.end_date >= m.month)
    GROUP BY m.month
),
churned AS (
    SELECT
        DATE_TRUNC('month', end_date) AS month,
        COUNT(DISTINCT customer_id) AS churned_customers
    FROM saas.subscriptions
    WHERE status = 'cancelled'
      AND end_date IS NOT NULL
    GROUP BY 1
)
SELECT
    a.month,
    a.active_customers,
    COALESCE(c.churned_customers, 0) AS churned_customers,
    COALESCE(c.churned_customers, 0)::NUMERIC
      / NULLIF(a.active_customers, 0) AS churn_rate
FROM active_base a
LEFT JOIN churned c
  ON a.month = c.month
ORDER BY a.month;


--03. Cohorot & Retention View :Signup cohort → monthly retention %

CREATE OR REPLACE VIEW saas.v_cohort_retention AS
WITH cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', signup_date) AS cohort_month
    FROM saas.customers
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
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
    WHERE i.invoice_date >= c.cohort_month
    GROUP BY 1,2
)

SELECT
    a.cohort_month,
    DATE_PART('month', AGE(a.revenue_month, a.cohort_month)) 
      + 12 * DATE_PART('year', AGE(a.revenue_month, a.cohort_month))
      AS month_index,
    a.active_customers * 1.0 / cs.cohort_size AS retention_pct
FROM activity a
JOIN cohort_sizes cs
  ON a.cohort_month = cs.cohort_month;
  
--05.Usage vs Churn
CREATE OR REPLACE VIEW saas.v_usage_vs_churn AS
WITH usage AS (
    SELECT
        customer_id,
        COUNT(*) AS total_events
    FROM saas.product_usage_events
    GROUP BY customer_id
)
SELECT
    s.status,
    AVG(COALESCE(u.total_events, 0)) AS avg_usage_events
FROM saas.subscriptions s
LEFT JOIN usage u
  ON s.customer_id = u.customer_id
GROUP BY s.status;

--06. LTV Distribution
CREATE OR REPLACE VIEW saas.v_ltv AS
SELECT
    c.customer_id,
    SUM(i.amount) AS lifetime_value
FROM saas.customers c
JOIN saas.subscriptions s
  ON c.customer_id = s.customer_id
JOIN saas.invoices i
  ON s.subscription_id = i.subscription_id
GROUP BY c.customer_id;

--06.High-Risk Customers
CREATE OR REPLACE VIEW saas.v_high_risk_customers AS
WITH usage AS (
    SELECT
        customer_id,
        COUNT(*) AS total_events
    FROM saas.product_usage_events
    GROUP BY customer_id
),
ltv AS (
    SELECT
        c.customer_id,
        SUM(i.amount) AS lifetime_value
    FROM saas.customers c
    JOIN saas.subscriptions s
      ON c.customer_id = s.customer_id
    JOIN saas.invoices i
      ON s.subscription_id = i.subscription_id
    GROUP BY c.customer_id
)
SELECT
    s.customer_id,
    COALESCE(u.total_events, 0) AS usage_events,
    COALESCE(l.lifetime_value, 0) AS lifetime_value,
    s.status
FROM saas.subscriptions s
LEFT JOIN usage u ON s.customer_id = u.customer_id
LEFT JOIN ltv l ON s.customer_id = l.customer_id
WHERE s.status = 'active'
  AND COALESCE(u.total_events, 0) < 5;

--07. for quick validation run:
SELECT * FROM saas.v_revenue_breakdown LIMIT 5;
SELECT * FROM saas.v_churn_monthly LIMIT 5;
SELECT * FROM saas.v_cohort_retention LIMIT 5;
