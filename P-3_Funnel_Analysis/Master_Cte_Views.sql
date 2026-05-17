-- ============================================================
-- PROJECT 3: Master CTE Report + Dashboard Views
-- ============================================================

USE FunnelAnalysis;
GO

-- ============================================================
-- MASTER SCRIPT: Full Funnel Report in One Query
-- 6 chained CTEs — shows advanced SQL architecture
-- ============================================================

WITH
-- CTE 1: All signup events
signups AS (
    SELECT user_id, event_date AS signup_date
    FROM events
    WHERE event_type = 'signed_up'
),

-- CTE 2: All onboarding completions
onboarded AS (
    SELECT user_id, event_date AS onboard_date
    FROM events
    WHERE event_type = 'completed_onboarding'
),

-- CTE 3: First purchases
purchasers AS (
    SELECT user_id, event_date AS purchase_date
    FROM events
    WHERE event_type = 'first_purchase'
),

-- CTE 4: Repeat buyers
repeat_buyers AS (
    SELECT user_id, event_date AS repeat_date
    FROM events
    WHERE event_type = 'second_purchase'
),

-- CTE 5: Stitch user journey together
user_journey AS (
    SELECT
        s.user_id,
        u.channel,
        u.device,
        u.city,
        s.signup_date,
        o.onboard_date,
        p.purchase_date,
        r.repeat_date,
        DATEDIFF(DAY, s.signup_date, o.onboard_date)   AS days_to_onboard,
        DATEDIFF(DAY, s.signup_date, p.purchase_date)  AS days_to_purchase,
        DATEDIFF(DAY, p.purchase_date, r.repeat_date)  AS days_between_purchases
    FROM signups s
    JOIN users u              ON s.user_id = u.user_id
    LEFT JOIN onboarded o     ON s.user_id = o.user_id
    LEFT JOIN purchasers p    ON s.user_id = p.user_id
    LEFT JOIN repeat_buyers r ON s.user_id = r.user_id
),

-- CTE 6: Stage classification
staged AS (
    SELECT *,
        CASE
            WHEN repeat_date   IS NOT NULL THEN 4
            WHEN purchase_date IS NOT NULL THEN 3
            WHEN onboard_date  IS NOT NULL THEN 2
            ELSE 1
        END AS max_stage_reached
    FROM user_journey
)

-- FINAL OUTPUT: Funnel summary by channel
SELECT
    channel,
    COUNT(*)                                                        AS total_users,
    SUM(CASE WHEN max_stage_reached >= 2 THEN 1 ELSE 0 END)        AS onboarded,
    SUM(CASE WHEN max_stage_reached >= 3 THEN 1 ELSE 0 END)        AS purchased,
    SUM(CASE WHEN max_stage_reached >= 4 THEN 1 ELSE 0 END)        AS repeat_buyers,
    ROUND(AVG(CAST(days_to_onboard AS FLOAT)), 1)                  AS avg_days_to_onboard,
    ROUND(AVG(CAST(days_to_purchase AS FLOAT)), 1)                 AS avg_days_to_purchase,
    ROUND(AVG(CAST(days_between_purchases AS FLOAT)), 1)           AS avg_days_between_purchases,
    ROUND(SUM(CASE WHEN max_stage_reached>=3 THEN 1.0 ELSE 0 END)
          * 100 / COUNT(*), 2)                                     AS overall_conv_pct
FROM staged
GROUP BY channel
ORDER BY overall_conv_pct DESC;
GO

-- ============================================================
-- DASHBOARD VIEWS FOR POWER BI
-- ============================================================

-- VIEW 1: Funnel Steps Summary (for funnel chart)
CREATE OR ALTER VIEW vw_funnel_summary AS
SELECT
    1 AS step_order, 'Signed Up'             AS funnel_step,
    COUNT(DISTINCT user_id)                  AS users
FROM events WHERE event_type='signed_up'
UNION ALL
SELECT 2, 'Completed Onboarding',
    COUNT(DISTINCT user_id)
FROM events WHERE event_type='completed_onboarding'
UNION ALL
SELECT 3, 'First Purchase',
    COUNT(DISTINCT user_id)
FROM events WHERE event_type='first_purchase'
UNION ALL
SELECT 4, 'Second Purchase',
    COUNT(DISTINCT user_id)
FROM events WHERE event_type='second_purchase';
GO

-- VIEW 2: Channel Conversion (for bar chart)
CREATE OR ALTER VIEW vw_channel_conversion AS
SELECT
    u.channel,
    COUNT(DISTINCT u.user_id)                                                           AS signups,
    COUNT(DISTINCT CASE WHEN e.event_type='completed_onboarding' THEN e.user_id END)   AS onboarded,
    COUNT(DISTINCT CASE WHEN e.event_type='first_purchase'       THEN e.user_id END)   AS purchased,
    COUNT(DISTINCT CASE WHEN e.event_type='second_purchase'      THEN e.user_id END)   AS repeat_buyers,
    ROUND(COUNT(DISTINCT CASE WHEN e.event_type='first_purchase' THEN e.user_id END)
          * 100.0 / NULLIF(COUNT(DISTINCT u.user_id), 0), 2)                           AS conv_rate_pct
FROM users u
LEFT JOIN events e ON u.user_id = e.user_id
GROUP BY u.channel;
GO

-- VIEW 3: Cohort Retention (for matrix / heatmap)
CREATE OR ALTER VIEW vw_cohort_matrix AS
SELECT
    YEAR(u.signup_date)                                                                  AS yr,
    DATEPART(WEEK, u.signup_date)                                                        AS wk,
    COUNT(DISTINCT u.user_id)                                                            AS cohort_size,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(DAY,u.signup_date,e.event_date)<=30
                AND e.event_type='first_purchase' THEN u.user_id END)
          * 100.0 / NULLIF(COUNT(DISTINCT u.user_id),0), 2)                             AS retention_30d,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(DAY,u.signup_date,e.event_date)<=60
                AND e.event_type='first_purchase' THEN u.user_id END)
          * 100.0 / NULLIF(COUNT(DISTINCT u.user_id),0), 2)                             AS retention_60d,
    ROUND(COUNT(DISTINCT CASE WHEN DATEDIFF(DAY,u.signup_date,e.event_date)<=90
                AND e.event_type='first_purchase' THEN u.user_id END)
          * 100.0 / NULLIF(COUNT(DISTINCT u.user_id),0), 2)                             AS retention_90d
FROM users u
LEFT JOIN events e ON u.user_id = e.user_id
GROUP BY YEAR(u.signup_date), DATEPART(WEEK, u.signup_date);
GO

-- VIEW 4: Drop-off by Stage (for waterfall chart)
CREATE OR ALTER VIEW vw_dropoff_by_stage AS
WITH stages AS (
    SELECT u.user_id, u.channel, u.device,
        MAX(CASE WHEN e.event_type='signed_up'            THEN 1 ELSE 0 END) AS s1,
        MAX(CASE WHEN e.event_type='completed_onboarding' THEN 1 ELSE 0 END) AS s2,
        MAX(CASE WHEN e.event_type='first_purchase'       THEN 1 ELSE 0 END) AS s3,
        MAX(CASE WHEN e.event_type='second_purchase'      THEN 1 ELSE 0 END) AS s4
    FROM users u LEFT JOIN events e ON u.user_id=e.user_id
    GROUP BY u.user_id, u.channel, u.device
)
SELECT
    CASE
        WHEN s1=1 AND s2=0              THEN 'Dropped at Onboarding'
        WHEN s2=1 AND s3=0              THEN 'Dropped after Onboarding'
        WHEN s3=1 AND s4=0              THEN 'One-time Buyers'
        WHEN s4=1                        THEN 'Repeat Buyers'
        ELSE                                  'Unknown'
    END     AS stage,
    channel,
    device,
    COUNT(*) AS users
FROM stages
GROUP BY
    CASE
        WHEN s1=1 AND s2=0              THEN 'Dropped at Onboarding'
        WHEN s2=1 AND s3=0              THEN 'Dropped after Onboarding'
        WHEN s3=1 AND s4=0              THEN 'One-time Buyers'
        WHEN s4=1                        THEN 'Repeat Buyers'
        ELSE                                  'Unknown'
    END,
    channel, device;
GO

-- Quick verify
SELECT * FROM vw_funnel_summary ORDER BY step_order;
SELECT TOP 5 * FROM vw_channel_conversion;
SELECT TOP 5 * FROM vw_cohort_matrix ORDER BY yr, wk;
GO
