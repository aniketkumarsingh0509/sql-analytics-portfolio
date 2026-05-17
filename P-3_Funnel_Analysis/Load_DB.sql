-- ============================================================
-- PROJECT 3: User Funnel & Behavioural Drop-off Analysis
-- Tool: SQL Server Management Studio (SSMS)
-- Dataset: Self-generated (script below creates the data)
-- Author: Aniket Kumar Singh
-- ============================================================

CREATE DATABASE FunnelAnalysis;
GO

USE FunnelAnalysis;
GO

-- ============================================================
-- STEP 1: Create Schema
-- ============================================================

DROP TABLE IF EXISTS events;
DROP TABLE IF EXISTS users;

CREATE TABLE users (
    user_id         INT             PRIMARY KEY,
    signup_date     DATE,
    channel         VARCHAR(30),    -- organic, paid_search, referral, email, social
    segment         VARCHAR(20),    -- new, returning
    city            VARCHAR(30),
    device          VARCHAR(20)     -- mobile, desktop, tablet
);

CREATE TABLE events (
    event_id        INT             IDENTITY(1,1) PRIMARY KEY,
    user_id         INT,
    event_type      VARCHAR(40),    -- signed_up, completed_onboarding, first_purchase, second_purchase
    event_date      DATE,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);
GO

-- ============================================================
-- STEP 2: Generate Realistic Sample Data (5000 users)
-- This script simulates a real product funnel with drop-offs
-- ============================================================

-- Generate 5000 users
WITH nums AS (
    SELECT TOP 5000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.objects a CROSS JOIN sys.objects b
)
INSERT INTO users (user_id, signup_date, channel, segment, city, device)
SELECT
    n AS user_id,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, CAST('2024-01-01' AS DATE)) AS signup_date,
    CASE (ABS(CHECKSUM(NEWID())) % 5)
        WHEN 0 THEN 'organic'
        WHEN 1 THEN 'paid_search'
        WHEN 2 THEN 'referral'
        WHEN 3 THEN 'email'
        ELSE        'social'
    END AS channel,
    CASE WHEN n % 3 = 0 THEN 'returning' ELSE 'new' END AS segment,
    CASE (ABS(CHECKSUM(NEWID())) % 6)
        WHEN 0 THEN 'Mumbai'
        WHEN 1 THEN 'Delhi'
        WHEN 2 THEN 'Bangalore'
        WHEN 3 THEN 'Hyderabad'
        WHEN 4 THEN 'Chennai'
        ELSE        'Pune'
    END AS city,
    CASE (ABS(CHECKSUM(NEWID())) % 3)
        WHEN 0 THEN 'mobile'
        WHEN 1 THEN 'desktop'
        ELSE        'tablet'
    END AS device
FROM nums;
GO

-- All 5000 signed up
INSERT INTO events (user_id, event_type, event_date)
SELECT user_id, 'signed_up', signup_date FROM users;
GO

-- ~72% complete onboarding (within 3 days of signup)
INSERT INTO events (user_id, event_type, event_date)
SELECT
    user_id,
    'completed_onboarding',
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 3 + 1, signup_date)
FROM users
WHERE ABS(CHECKSUM(NEWID())) % 100 < 72;
GO

-- ~45% of onboarded users make first purchase (within 14 days)
INSERT INTO events (user_id, event_type, event_date)
SELECT
    e.user_id,
    'first_purchase',
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 14 + 1, e.event_date)
FROM events e
WHERE e.event_type = 'completed_onboarding'
  AND ABS(CHECKSUM(NEWID())) % 100 < 45;
GO

-- ~40% of first purchasers make a second purchase (within 30 days)
INSERT INTO events (user_id, event_type, event_date)
SELECT
    e.user_id,
    'second_purchase',
    DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 30 + 1, e.event_date)
FROM events e
WHERE e.event_type = 'first_purchase'
  AND ABS(CHECKSUM(NEWID())) % 100 < 40;
GO

-- Verify data loaded
SELECT event_type, COUNT(*) AS cnt FROM events GROUP BY event_type;
GO
