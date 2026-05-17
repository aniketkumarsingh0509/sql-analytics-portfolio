-- ============================================================
-- PROJECT 2: Revenue Trends & Product Performance
-- ============================================================

USE SalesAnalysis;
GO

-- ============================================================
-- ANALYSIS 1: Monthly Revenue with MoM Growth
-- ============================================================

WITH monthly_revenue AS (
    SELECT
        YEAR(order_date)                            AS yr,
        MONTH(order_date)                           AS mo,
        FORMAT(order_date, 'yyyy-MM')               AS month_label,
        ROUND(SUM(sales), 2)                        AS revenue,
        ROUND(SUM(profit), 2)                       AS profit,
        COUNT(DISTINCT order_id)                    AS total_orders,
        COUNT(DISTINCT customer_id)                 AS unique_customers
    FROM orders
    GROUP BY YEAR(order_date), MONTH(order_date), FORMAT(order_date, 'yyyy-MM')
)
SELECT
    month_label,
    revenue,
    profit,
    total_orders,
    unique_customers,
    LAG(revenue) OVER (ORDER BY yr, mo)     AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY yr, mo)) * 100.0
        / NULLIF(LAG(revenue) OVER (ORDER BY yr, mo), 0)
    , 2)                                    AS mom_growth_pct,
    ROUND(AVG(revenue) OVER (
        ORDER BY yr, mo
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                   AS rolling_3m_avg_revenue
FROM monthly_revenue
ORDER BY yr, mo;
GO

-- ============================================================
-- ANALYSIS 2: Quarterly Revenue & YoY Comparison
-- ============================================================

WITH quarterly AS (
    SELECT
        YEAR(order_date)                    AS yr,
        DATEPART(QUARTER, order_date)       AS qtr,
        CONCAT('Q', DATEPART(QUARTER, order_date), '-', YEAR(order_date)) AS quarter_label,
        ROUND(SUM(sales), 2)                AS revenue,
        ROUND(SUM(profit), 2)               AS profit,
        ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2) AS profit_margin_pct
    FROM orders
    GROUP BY YEAR(order_date), DATEPART(QUARTER, order_date)
)
SELECT
    quarter_label,
    revenue,
    profit,
    profit_margin_pct,
    LAG(revenue, 4) OVER (ORDER BY yr, qtr)    AS same_qtr_last_year,
    ROUND(
        (revenue - LAG(revenue, 4) OVER (ORDER BY yr, qtr)) * 100.0
        / NULLIF(LAG(revenue, 4) OVER (ORDER BY yr, qtr), 0)
    , 2)                                        AS yoy_growth_pct
FROM quarterly
ORDER BY yr, qtr;
GO

-- ============================================================
-- ANALYSIS 3: Top 10 Products by Revenue & Profit
-- ============================================================

SELECT TOP 10
    p.product_name,
    p.category,
    p.sub_category,
    ROUND(SUM(o.sales), 2)                                      AS total_revenue,
    ROUND(SUM(o.profit), 2)                                     AS total_profit,
    ROUND(SUM(o.profit) * 100.0 / NULLIF(SUM(o.sales), 0), 2)  AS profit_margin_pct,
    SUM(o.quantity)                                             AS units_sold,
    COUNT(DISTINCT o.order_id)                                  AS order_count
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_name, p.category, p.sub_category
ORDER BY total_revenue DESC;
GO

-- ============================================================
-- ANALYSIS 4: Loss-Making Products (Negative Margin)
-- ============================================================

SELECT
    p.product_name,
    p.category,
    p.sub_category,
    ROUND(SUM(o.sales), 2)                                      AS total_revenue,
    ROUND(SUM(o.profit), 2)                                     AS total_profit,
    ROUND(SUM(o.profit) * 100.0 / NULLIF(SUM(o.sales), 0), 2)  AS profit_margin_pct,
    ROUND(AVG(o.discount), 2)                                   AS avg_discount
FROM orders o
JOIN products p ON o.product_id = p.product_id
GROUP BY p.product_name, p.category, p.sub_category
HAVING SUM(o.profit) < 0
ORDER BY total_profit ASC;
GO

-- ============================================================
-- ANALYSIS 5: Category Revenue Contribution %
-- ============================================================

WITH category_rev AS (
    SELECT
        p.category,
        p.sub_category,
        ROUND(SUM(o.sales), 2)      AS revenue,
        ROUND(SUM(o.profit), 2)     AS profit
    FROM orders o
    JOIN products p ON o.product_id = p.product_id
    GROUP BY p.category, p.sub_category
)
SELECT
    category,
    sub_category,
    revenue,
    profit,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (), 2)                AS pct_of_total_revenue,
    ROUND(revenue * 100.0 / SUM(revenue) OVER (PARTITION BY category), 2) AS pct_within_category,
    RANK() OVER (PARTITION BY category ORDER BY revenue DESC)        AS rank_in_category
FROM category_rev
ORDER BY category, revenue DESC;
GO

-- ============================================================
-- ANALYSIS 6: Regional Performance
-- ============================================================

SELECT
    c.region,
    c.state,
    COUNT(DISTINCT o.order_id)                                      AS total_orders,
    COUNT(DISTINCT o.customer_id)                                   AS unique_customers,
    ROUND(SUM(o.sales), 2)                                          AS revenue,
    ROUND(SUM(o.profit), 2)                                         AS profit,
    ROUND(SUM(o.profit) * 100.0 / NULLIF(SUM(o.sales), 0), 2)      AS profit_margin_pct,
    ROUND(AVG(o.discount), 3)                                       AS avg_discount,
    ROUND(SUM(o.sales) / COUNT(DISTINCT o.order_id), 2)             AS avg_order_value
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
GROUP BY c.region, c.state
ORDER BY revenue DESC;
GO

-- ============================================================
-- ANALYSIS 7: Shipping Performance — Late Delivery Rate
-- ============================================================

SELECT
    ship_mode,
    COUNT(*)                                                        AS total_orders,
    SUM(CASE WHEN DATEDIFF(DAY, order_date, ship_date) > 
        CASE ship_mode
            WHEN 'First Class'    THEN 2
            WHEN 'Second Class'   THEN 5
            WHEN 'Standard Class' THEN 7
            ELSE 1
        END THEN 1 ELSE 0 END)                                     AS late_deliveries,
    ROUND(SUM(CASE WHEN DATEDIFF(DAY, order_date, ship_date) >
        CASE ship_mode
            WHEN 'First Class'    THEN 2
            WHEN 'Second Class'   THEN 5
            WHEN 'Standard Class' THEN 7
            ELSE 1
        END THEN 1.0 ELSE 0 END) * 100 / COUNT(*), 2)              AS late_delivery_rate_pct,
    ROUND(AVG(CAST(DATEDIFF(DAY, order_date, ship_date) AS FLOAT)), 1) AS avg_ship_days
FROM orders
GROUP BY ship_mode
ORDER BY late_delivery_rate_pct DESC;
GO

-- ============================================================
-- ANALYSIS 8: Discount Impact on Profit
-- High discount = negative profit?
-- ============================================================

SELECT
    CASE
        WHEN discount = 0           THEN '0% — No Discount'
        WHEN discount <= 0.10       THEN '1–10%'
        WHEN discount <= 0.20       THEN '11–20%'
        WHEN discount <= 0.30       THEN '21–30%'
        ELSE                             '30%+ Heavy Discount'
    END                                                             AS discount_bucket,
    COUNT(*)                                                        AS orders,
    ROUND(SUM(sales), 2)                                            AS total_revenue,
    ROUND(SUM(profit), 2)                                           AS total_profit,
    ROUND(AVG(profit), 2)                                           AS avg_profit_per_order,
    ROUND(SUM(profit) * 100.0 / NULLIF(SUM(sales), 0), 2)          AS profit_margin_pct
FROM orders
GROUP BY
    CASE
        WHEN discount = 0           THEN '0% — No Discount'
        WHEN discount <= 0.10       THEN '1–10%'
        WHEN discount <= 0.20       THEN '11–20%'
        WHEN discount <= 0.30       THEN '21–30%'
        ELSE                             '30%+ Heavy Discount'
    END
ORDER BY profit_margin_pct DESC;
GO
