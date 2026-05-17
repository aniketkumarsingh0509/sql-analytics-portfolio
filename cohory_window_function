-- ============================================================
-- PROJECT 1: Cohort Analysis & Window Functions
-- ============================================================

USE ChurnAnalysis;
GO

-- ============================================================
-- ANALYSIS 8: Cohort Buckets — Churn Rate by Tenure Group
-- ============================================================

WITH cohort_data AS (
    SELECT
        customer_id,
        churn,
        CASE
            WHEN tenure BETWEEN 0  AND 12  THEN '01. 0–12 months'
            WHEN tenure BETWEEN 13 AND 24  THEN '02. 13–24 months'
            WHEN tenure BETWEEN 25 AND 48  THEN '03. 25–48 months'
            ELSE                                 '04. 48+ months'
        END AS cohort
    FROM customers
)
SELECT
    cohort,
    COUNT(*)                                                                        AS total_customers,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                                AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct,
    ROUND(100 - SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2) AS retention_rate_pct
FROM cohort_data
GROUP BY cohort
ORDER BY cohort;
GO

-- ============================================================
-- ANALYSIS 9: Churn Rate by Contract + Cohort Combined
-- Shows which cohort + contract combo has worst churn
-- ============================================================

WITH combined AS (
    SELECT
        contract,
        CASE
            WHEN tenure BETWEEN 0  AND 12  THEN '0–12 months'
            WHEN tenure BETWEEN 13 AND 24  THEN '13–24 months'
            WHEN tenure BETWEEN 25 AND 48  THEN '25–48 months'
            ELSE                                 '48+ months'
        END AS cohort,
        churn
    FROM customers
)
SELECT
    contract,
    cohort,
    COUNT(*)                                                                        AS total,
    SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                                AS churned,
    ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)  AS churn_rate_pct
FROM combined
GROUP BY contract, cohort
ORDER BY contract, cohort;
GO

-- ============================================================
-- ANALYSIS 10: WINDOW FUNCTION — Running Churn Count by Tenure
-- Shows how churn accumulates as tenure increases
-- ============================================================

WITH tenure_churn AS (
    SELECT
        tenure,
        COUNT(*)                                             AS total_at_tenure,
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)     AS churned_at_tenure
    FROM customers
    GROUP BY tenure
)
SELECT
    tenure,
    total_at_tenure,
    churned_at_tenure,
    SUM(churned_at_tenure)  OVER (ORDER BY tenure ROWS UNBOUNDED PRECEDING)  AS running_total_churned,
    SUM(total_at_tenure)    OVER (ORDER BY tenure ROWS UNBOUNDED PRECEDING)  AS running_total_users,
    ROUND(
        SUM(churned_at_tenure) OVER (ORDER BY tenure ROWS UNBOUNDED PRECEDING) * 100.0
        / SUM(total_at_tenure) OVER (ORDER BY tenure ROWS UNBOUNDED PRECEDING),
    2)  AS cumulative_churn_rate_pct
FROM tenure_churn
ORDER BY tenure;
GO

-- ============================================================
-- ANALYSIS 11: WINDOW FUNCTION — Customer Risk Ranking
-- Rank all active customers by churn risk within each contract type
-- High monthly charges + low tenure = highest risk
-- ============================================================

SELECT
    customer_id,
    contract,
    tenure,
    monthly_charges,
    internet_service,
    RANK() OVER (
        PARTITION BY contract
        ORDER BY monthly_charges DESC, tenure ASC
    )   AS risk_rank_within_contract,
    RANK() OVER (
        ORDER BY monthly_charges DESC, tenure ASC
    )   AS overall_risk_rank
FROM customers
WHERE churn = 'No'   -- Active customers only — who might churn next?
ORDER BY overall_risk_rank;
GO

-- ============================================================
-- ANALYSIS 12: WINDOW FUNCTION — Monthly Charges Percentile
-- Where does each customer sit vs their contract peers?
-- ============================================================

SELECT
    customer_id,
    contract,
    monthly_charges,
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY contract
        ORDER BY monthly_charges
    ) * 100, 1)  AS charges_percentile_in_contract,
    churn
FROM customers
ORDER BY contract, monthly_charges DESC;
GO

-- ============================================================
-- ANALYSIS 13: LAG — Churn Pattern by Tenure (Month-on-Month)
-- ============================================================

WITH monthly_churn AS (
    SELECT
        tenure                                                          AS month,
        SUM(CASE WHEN churn = 'Yes' THEN 1 ELSE 0 END)                AS churned,
        COUNT(*)                                                        AS total,
        ROUND(SUM(CASE WHEN churn = 'Yes' THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2) AS churn_rate
    FROM customers
    GROUP BY tenure
)
SELECT
    month,
    churned,
    total,
    churn_rate,
    LAG(churn_rate) OVER (ORDER BY month)   AS prev_month_churn_rate,
    ROUND(churn_rate - LAG(churn_rate) OVER (ORDER BY month), 2)  AS churn_rate_change
FROM monthly_churn
ORDER BY month;
GO

