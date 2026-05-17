-- ============================================================
-- PROJECT 1: Churn Metrics & Segmentation
-- ============================================================

USE ChurnAnalysis;
GO

-- ============================================================
-- ANALYSIS 1: Overall Churn Rate
-- ============================================================

SELECT
    churn,
    COUNT(*)                                                        AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)             AS churn_pct
FROM customers
GROUP BY churn;
GO

-- ============================================================
-- ANALYSIS 2: Churn vs Retained — Avg Tenure & Charges
-- ============================================================

SELECT
    churn,
    COUNT(*)                          AS customers,
    ROUND(AVG(tenure), 1)             AS avg_tenure_months,
    ROUND(AVG(monthly_charges), 2)    AS avg_monthly_charges,
    ROUND(AVG(total_charges), 2)      AS avg_total_charges
FROM customers
GROUP BY churn;
GO

-- ============================================================
-- ANALYSIS 3: Churn Rate by Contract Type
-- ============================================================

SELECT
    contract,
    COUNT(*)                                                                AS total,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                        AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct
FROM customers
GROUP BY contract
ORDER BY churn_rate_pct DESC;
GO

-- ============================================================
-- ANALYSIS 4: Churn Rate by Payment Method
-- ============================================================

SELECT
    payment_method,
    COUNT(*)                                                                        AS total,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                                AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct
FROM customers
GROUP BY payment_method
ORDER BY churn_rate_pct DESC;
GO

-- ============================================================
-- ANALYSIS 5: Churn Rate by Internet Service
-- ============================================================

SELECT
    internet_service,
    COUNT(*)                                                                        AS total,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                                AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct
FROM customers
GROUP BY internet_service
ORDER BY churn_rate_pct DESC;
GO

-- ============================================================
-- ANALYSIS 6: High-Value Churned Customers
-- Customers paying above average who still left
-- ============================================================

SELECT
    customer_id,
    tenure,
    contract,
    monthly_charges,
    total_charges,
    payment_method
FROM customers
WHERE churn = 'Yes'
  AND monthly_charges > (SELECT AVG(monthly_charges) FROM customers)
ORDER BY monthly_charges DESC;
GO

-- ============================================================
-- ANALYSIS 7: Risk Segment — No Support + No Security
-- Customers with no tech support AND no online security
-- These are highest churn risk profiles
-- ============================================================

SELECT
    tech_support,
    online_security,
    COUNT(*)                                                                        AS total,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                                AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct
FROM customers
GROUP BY tech_support, online_security
ORDER BY churn_rate_pct DESC;
GO

