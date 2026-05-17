-- ============================================================
-- PROJECT 2: Sales Performance & RFM Analytics
-- Tool: SQL Server Management Studio (SSMS)
-- Dataset: Superstore Sales (Kaggle)
-- Author: Aniket Kumar Singh
-- ============================================================

-- ============================================================
-- STEP 1: Setup Database & Normalised Schema
-- ============================================================

CREATE DATABASE SalesAnalysis;
GO

USE SalesAnalysis;
GO

-- Customers dimension
DROP TABLE IF EXISTS customers;
CREATE TABLE customers (
    customer_id     VARCHAR(20)  PRIMARY KEY,
    customer_name   VARCHAR(100),
    segment         VARCHAR(30),   -- Consumer, Corporate, Home Office
    region          VARCHAR(30),
    state           VARCHAR(50),
    city            VARCHAR(50)
);

-- Products dimension
DROP TABLE IF EXISTS products;
CREATE TABLE products (
    product_id      VARCHAR(30)  PRIMARY KEY,
    category        VARCHAR(30),
    sub_category    VARCHAR(30),
    product_name    VARCHAR(200)
);

-- Orders fact table
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id        VARCHAR(20),
    order_date      DATE,
    ship_date       DATE,
    ship_mode       VARCHAR(30),
    customer_id     VARCHAR(20),
    product_id      VARCHAR(30),
    sales           DECIMAL(10,2),
    quantity        INT,
    discount        DECIMAL(5,2),
    profit          DECIMAL(10,2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (product_id)  REFERENCES products(product_id)
);

-- Returns table
DROP TABLE IF EXISTS returns;
CREATE TABLE returns (
    order_id        VARCHAR(20),
    returned        VARCHAR(5)    -- Yes/No
);
GO

-- ============================================================
-- NOTE: Import the Superstore CSV, then split into the 4 tables
-- above using INSERT INTO ... SELECT FROM the staging flat table
-- ============================================================
