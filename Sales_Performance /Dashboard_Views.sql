-- ============================================================
-- PROJECT 2: Dashboard Views for Power BI
-- ============================================================

USE SalesAnalysis;
GO

-- VIEW 1: Monthly Revenue Trend (for line chart)
CREATE OR ALTER VIEW vw_monthly_revenue_trend AS
WITH monthly AS (
    SELECT
        YEAR(order_date)            AS yr,
        MONTH(order_date)           AS mo,
        FORMAT(order_date,'yyyy-MM') AS month_label,
        ROUND(SUM(sales),2)         AS revenue,
        ROUND(SUM(profit),2)        AS profit,
        COUNT(DISTINCT order_id)    AS orders
    FROM orders
    GROUP BY YEAR(order_date), MONTH(order_date), FORMAT(order_date,'yyyy-MM')
)
SELECT
    month_label, revenue, profit, orders,
    LAG(revenue) OVER (ORDER BY yr, mo)  AS prev_month_revenue,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY yr, mo)) * 100.0
          / NULLIF(LAG(revenue) OVER (ORDER BY yr, mo),0), 2) AS mom_growth_pct,
    ROUND(AVG(revenue) OVER (ORDER BY yr, mo ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS rolling_3m_avg
FROM monthly;
GO

-- VIEW 2: Category & Sub-category Performance (for treemap / bar)
CREATE OR ALTER VIEW vw_category_performance AS
SELECT
    p.category,
    p.sub_category,
    ROUND(SUM(o.sales),2)                                           AS revenue,
    ROUND(SUM(o.profit),2)                                          AS profit,
    ROUND(SUM(o.profit)*100.0/NULLIF(SUM(o.sales),0),2)            AS margin_pct,
    SUM(o.quantity)                                                 AS units_sold,
    ROUND(revenue*100.0/SUM(SUM(o.sales)) OVER(),2)                AS pct_of_total
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.category, p.sub_category;
GO

-- VIEW 3: Regional KPIs (for map visual)
CREATE OR ALTER VIEW vw_regional_kpi AS
SELECT
    c.region,
    c.state,
    COUNT(DISTINCT o.order_id)                                      AS orders,
    COUNT(DISTINCT o.customer_id)                                   AS customers,
    ROUND(SUM(o.sales),2)                                           AS revenue,
    ROUND(SUM(o.profit),2)                                          AS profit,
    ROUND(SUM(o.profit)*100.0/NULLIF(SUM(o.sales),0),2)            AS margin_pct
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region, c.state;
GO

-- VIEW 4: RFM Segments (for donut + table)
CREATE OR ALTER VIEW vw_rfm_segments AS
WITH rfm_base AS (
    SELECT customer_id,
        DATEDIFF(DAY, MAX(order_date), CAST('2017-12-31' AS DATE)) AS recency_days,
        COUNT(DISTINCT order_id)                                    AS frequency,
        ROUND(SUM(sales),2)                                         AS monetary
    FROM orders GROUP BY customer_id
),
rfm_scores AS (
    SELECT *, 
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency)          AS f_score,
        NTILE(5) OVER (ORDER BY monetary)           AS m_score
    FROM rfm_base
)
SELECT
    customer_id,
    recency_days, frequency, monetary,
    r_score, f_score, m_score,
    CASE
        WHEN r_score>=4 AND f_score>=4 AND m_score>=4  THEN 'Champions'
        WHEN r_score>=3 AND f_score>=3                  THEN 'Loyal Customers'
        WHEN r_score>=4 AND f_score<=2                  THEN 'Recent Customers'
        WHEN r_score>=3 AND m_score>=3                  THEN 'Potential Loyalists'
        WHEN r_score<=2 AND f_score>=3 AND m_score>=3   THEN 'At Risk'
        WHEN r_score<=2 AND f_score>=4                  THEN 'Cannot Lose Them'
        WHEN r_score<=2 AND f_score<=2 AND m_score<=2   THEN 'Lost'
        WHEN m_score>=4 AND f_score<=2                  THEN 'Big Spenders'
        ELSE                                                 'Need Attention'
    END AS customer_segment
FROM rfm_scores;
GO

-- VIEW 5: Discount vs Profit (for scatter / bar)
CREATE OR ALTER VIEW vw_discount_impact AS
SELECT
    CASE
        WHEN discount = 0      THEN '0% No Discount'
        WHEN discount <= 0.10  THEN '1–10%'
        WHEN discount <= 0.20  THEN '11–20%'
        WHEN discount <= 0.30  THEN '21–30%'
        ELSE                        '30%+ Heavy'
    END                                                             AS discount_bucket,
    COUNT(*)                                                        AS orders,
    ROUND(SUM(sales),2)                                             AS revenue,
    ROUND(SUM(profit),2)                                            AS profit,
    ROUND(SUM(profit)*100.0/NULLIF(SUM(sales),0),2)                AS margin_pct
FROM orders
GROUP BY
    CASE
        WHEN discount = 0      THEN '0% No Discount'
        WHEN discount <= 0.10  THEN '1–10%'
        WHEN discount <= 0.20  THEN '11–20%'
        WHEN discount <= 0.30  THEN '21–30%'
        ELSE                        '30%+ Heavy'
    END;
GO

SELECT TOP 3 * FROM vw_monthly_revenue_trend;
SELECT TOP 3 * FROM vw_category_performance;
SELECT TOP 3 * FROM vw_regional_kpi;
SELECT TOP 3 * FROM vw_rfm_segments;
SELECT TOP 3 * FROM vw_discount_impact;
GO
