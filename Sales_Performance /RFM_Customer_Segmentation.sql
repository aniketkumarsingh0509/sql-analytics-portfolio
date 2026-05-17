-- ============================================================
-- PROJECT 2: RFM Customer Segmentation
-- RFM = Recency, Frequency, Monetary — built entirely in SQL
-- ============================================================

USE SalesAnalysis;
GO

-- ============================================================
-- STEP 1: Build the RFM Base Table
-- ============================================================

WITH rfm_base AS (
    SELECT
        customer_id,
        DATEDIFF(DAY, MAX(order_date), CAST('2017-12-31' AS DATE))  AS recency_days,   -- days since last order
        COUNT(DISTINCT order_id)                                      AS frequency,       -- number of orders
        ROUND(SUM(sales), 2)                                          AS monetary         -- total spend
    FROM orders
    GROUP BY customer_id
),

-- ============================================================
-- STEP 2: Score each dimension 1–5 using NTILE
-- ============================================================

rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        -- Lower recency = better (bought recently) so reverse order
        NTILE(5) OVER (ORDER BY recency_days DESC)   AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)        AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)         AS m_score
    FROM rfm_base
),

-- ============================================================
-- STEP 3: Calculate combined RFM score and label segments
-- ============================================================

rfm_labelled AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score + f_score + m_score)   AS total_rfm_score,
        CAST(r_score AS VARCHAR) + CAST(f_score AS VARCHAR) + CAST(m_score AS VARCHAR) AS rfm_cell
    FROM rfm_scores
)
SELECT
    r.customer_id,
    c.customer_name,
    c.segment,
    c.region,
    r.recency_days,
    r.frequency,
    r.monetary,
    r.r_score,
    r.f_score,
    r.m_score,
    r.total_rfm_score,
    r.rfm_cell,
    -- Segment labels based on RFM logic
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4        THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                          THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                          THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 3         THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3         THEN 'At Risk'
        WHEN r_score <= 2 AND f_score >= 4                          THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2         THEN 'Lost'
        WHEN m_score >= 4 AND f_score <= 2                          THEN 'Big Spenders'
        ELSE                                                              'Need Attention'
    END AS customer_segment
FROM rfm_labelled r
JOIN customers c ON r.customer_id = c.customer_id
ORDER BY total_rfm_score DESC;
GO

-- ============================================================
-- ANALYSIS: RFM Segment Summary
-- ============================================================

WITH rfm_base AS (
    SELECT customer_id,
        DATEDIFF(DAY, MAX(order_date), CAST('2017-12-31' AS DATE))  AS recency_days,
        COUNT(DISTINCT order_id)                                      AS frequency,
        ROUND(SUM(sales), 2)                                          AS monetary
    FROM orders GROUP BY customer_id
),
rfm_scores AS (
    SELECT customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)   AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)        AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)         AS m_score
    FROM rfm_base
)
SELECT
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4        THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                          THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                          THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 3         THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3         THEN 'At Risk'
        WHEN r_score <= 2 AND f_score >= 4                          THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2         THEN 'Lost'
        WHEN m_score >= 4 AND f_score <= 2                          THEN 'Big Spenders'
        ELSE                                                              'Need Attention'
    END                                                             AS customer_segment,
    COUNT(*)                                                        AS customer_count,
    ROUND(AVG(recency_days), 0)                                     AS avg_recency_days,
    ROUND(AVG(CAST(frequency AS FLOAT)), 1)                         AS avg_orders,
    ROUND(AVG(monetary), 2)                                         AS avg_spend,
    ROUND(SUM(monetary), 2)                                         AS total_revenue
FROM rfm_scores
GROUP BY
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4        THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3                          THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                          THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 3         THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3         THEN 'At Risk'
        WHEN r_score <= 2 AND f_score >= 4                          THEN 'Cannot Lose Them'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2         THEN 'Lost'
        WHEN m_score >= 4 AND f_score <= 2                          THEN 'Big Spenders'
        ELSE                                                              'Need Attention'
    END
ORDER BY total_revenue DESC;
GO

-- ============================================================
-- STORED PROCEDURE: Monthly KPI Report
-- Run this to get a full snapshot — like your automated pipelines
-- ============================================================

CREATE OR ALTER PROCEDURE sp_monthly_kpi_report
    @report_year  INT,
    @report_month INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_date DATE = DATEFROMPARTS(@report_year, @report_month, 1);
    DECLARE @end_date   DATE = EOMONTH(@start_date);
    DECLARE @prev_start DATE = DATEADD(MONTH, -1, @start_date);
    DECLARE @prev_end   DATE = DATEADD(DAY, -1, @start_date);

    -- Current month KPIs
    SELECT
        'Current Month'                                             AS period,
        FORMAT(@start_date, 'MMM yyyy')                            AS month,
        COUNT(DISTINCT order_id)                                    AS total_orders,
        COUNT(DISTINCT customer_id)                                 AS unique_customers,
        ROUND(SUM(sales), 2)                                        AS revenue,
        ROUND(SUM(profit), 2)                                       AS profit,
        ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2)      AS profit_margin_pct,
        ROUND(SUM(sales) / NULLIF(COUNT(DISTINCT order_id), 0), 2) AS avg_order_value
    FROM orders
    WHERE order_date BETWEEN @start_date AND @end_date

    UNION ALL

    -- Previous month KPIs
    SELECT
        'Previous Month',
        FORMAT(@prev_start, 'MMM yyyy'),
        COUNT(DISTINCT order_id),
        COUNT(DISTINCT customer_id),
        ROUND(SUM(sales), 2),
        ROUND(SUM(profit), 2),
        ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2),
        ROUND(SUM(sales) / NULLIF(COUNT(DISTINCT order_id), 0), 2)
    FROM orders
    WHERE order_date BETWEEN @prev_start AND @prev_end;
END;
GO

-- Run the stored procedure:
EXEC sp_monthly_kpi_report @report_year = 2017, @report_month = 11;
GO
