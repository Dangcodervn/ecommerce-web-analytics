-- 01_create_staging.sql
-- Tạo database, staging schema + tables, import CSV
-- Run order: 01 → 02 → 03 → 04

-- A. Database & Schema
CREATE DATABASE ecommerce_web_analytics;
GO

USE ecommerce_web_analytics;
GO

CREATE SCHEMA staging;
GO

-- B. Staging Tables (1:1 với CSV, không transform)

CREATE TABLE staging.products (
    product_id   INT            NOT NULL,
    created_at   DATETIME2      NOT NULL,
    product_name NVARCHAR(100)  NOT NULL,
    CONSTRAINT PK_stg_products PRIMARY KEY (product_id)
);
GO

CREATE TABLE staging.website_sessions (
    website_session_id  INT            NOT NULL,
    created_at          DATETIME2      NOT NULL,
    user_id             INT            NOT NULL,
    is_repeat_session   TINYINT        NOT NULL DEFAULT 0,  -- 0=new, 1=repeat
    utm_source          NVARCHAR(50)   NULL,
    utm_campaign        NVARCHAR(50)   NULL,
    utm_content         NVARCHAR(50)   NULL,
    device_type         NVARCHAR(20)   NOT NULL,            -- 'desktop'|'mobile'
    http_referer        NVARCHAR(255)  NULL,
    CONSTRAINT PK_stg_sessions PRIMARY KEY (website_session_id)
);
GO

CREATE TABLE staging.website_pageviews (
    website_pageview_id  INT            NOT NULL,
    created_at           DATETIME2      NOT NULL,
    website_session_id   INT            NOT NULL,
    pageview_url         NVARCHAR(255)  NOT NULL,
    CONSTRAINT PK_stg_pageviews PRIMARY KEY (website_pageview_id)
);
GO

CREATE TABLE staging.orders (
    order_id            INT            NOT NULL,
    created_at          DATETIME2      NOT NULL,
    website_session_id  INT            NOT NULL,
    user_id             INT            NOT NULL,
    primary_product_id  INT            NOT NULL,
    items_purchased     TINYINT        NOT NULL DEFAULT 1,
    price_usd           DECIMAL(8,2)   NOT NULL,
    cogs_usd            DECIMAL(8,2)   NOT NULL,
    CONSTRAINT PK_stg_orders PRIMARY KEY (order_id)
);
GO

CREATE TABLE staging.order_items (
    order_item_id   INT            NOT NULL,
    created_at      DATETIME2      NOT NULL,
    order_id        INT            NOT NULL,
    product_id      INT            NOT NULL,
    is_primary_item TINYINT        NOT NULL DEFAULT 0,  -- 1=primary, 0=cross-sell
    price_usd       DECIMAL(8,2)   NOT NULL,
    cogs_usd        DECIMAL(8,2)   NOT NULL,
    CONSTRAINT PK_stg_order_items PRIMARY KEY (order_item_id)
);
GO

CREATE TABLE staging.order_item_refunds (
    order_item_refund_id  INT            NOT NULL,
    created_at            DATETIME2      NOT NULL,
    order_item_id         INT            NOT NULL,
    order_id              INT            NOT NULL,
    refund_amount_usd     DECIMAL(8,2)   NOT NULL,
    CONSTRAINT PK_stg_refunds PRIMARY KEY (order_item_refund_id)
);
GO

-- C. BULK INSERT CSV → staging
-- NOTE: Thay đường dẫn nếu chạy trên máy khác

BULK INSERT staging.products
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\products.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.products' AS table_name, COUNT(*) AS row_count FROM staging.products;

BULK INSERT staging.website_sessions
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\website_sessions.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.website_sessions' AS table_name, COUNT(*) AS row_count FROM staging.website_sessions;

BULK INSERT staging.website_pageviews
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\website_pageviews.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.website_pageviews' AS table_name, COUNT(*) AS row_count FROM staging.website_pageviews;

BULK INSERT staging.orders
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\orders.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.orders' AS table_name, COUNT(*) AS row_count FROM staging.orders;

BULK INSERT staging.order_items
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\order_items.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.order_items' AS table_name, COUNT(*) AS row_count FROM staging.order_items;

BULK INSERT staging.order_item_refunds
FROM 'D:\Data Self Learning\Extra Projects\Web_Analytics\Data\order_item_refunds.csv'
WITH (FORMAT='CSV', FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='\n', TABLOCK);
GO
SELECT 'staging.order_item_refunds' AS table_name, COUNT(*) AS row_count FROM staging.order_item_refunds;
GO

-- Tổng kết
SELECT table_name = 'staging.products',           row_count = COUNT(*) FROM staging.products           UNION ALL
SELECT                'staging.website_sessions',               COUNT(*) FROM staging.website_sessions   UNION ALL
SELECT                'staging.website_pageviews',              COUNT(*) FROM staging.website_pageviews  UNION ALL
SELECT                'staging.orders',                         COUNT(*) FROM staging.orders             UNION ALL
SELECT                'staging.order_items',                    COUNT(*) FROM staging.order_items        UNION ALL
SELECT                'staging.order_item_refunds',             COUNT(*) FROM staging.order_item_refunds;
GO
