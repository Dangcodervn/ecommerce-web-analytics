-- ============================================================
-- 00_create_database.sql
-- SQL Server schema for Ecommerce Web Analytics
-- Run this script BEFORE importing CSV data
-- ============================================================

-- 1. Create and select database
CREATE DATABASE ecommerce_web_analytics;
GO

USE ecommerce_web_analytics;
GO

-- ============================================================
-- TABLE: products
-- Referenced by: order_items
-- ============================================================
CREATE TABLE products (
    product_id   INT            NOT NULL,
    created_at   DATETIME2      NOT NULL,
    product_name NVARCHAR(100)  NOT NULL,

    CONSTRAINT PK_products PRIMARY KEY (product_id)
);
GO

-- ============================================================
-- TABLE: website_sessions
-- Referenced by: website_pageviews, orders
-- Note: no utm_medium column in source data
--       channel logic uses utm_source + http_referer
-- ============================================================
CREATE TABLE website_sessions (
    website_session_id  INT            NOT NULL,
    created_at          DATETIME2      NOT NULL,
    user_id             INT            NOT NULL,
    is_repeat_session   TINYINT        NOT NULL DEFAULT 0,  -- 0 = new, 1 = repeat
    utm_source          NVARCHAR(50)   NULL,
    utm_campaign        NVARCHAR(50)   NULL,
    utm_content         NVARCHAR(50)   NULL,
    device_type         NVARCHAR(20)   NOT NULL,            -- 'desktop' | 'mobile'
    http_referer        NVARCHAR(255)  NULL,

    CONSTRAINT PK_website_sessions PRIMARY KEY (website_session_id)
);
GO

-- ============================================================
-- TABLE: website_pageviews
-- ============================================================
CREATE TABLE website_pageviews (
    website_pageview_id  INT            NOT NULL,
    created_at           DATETIME2      NOT NULL,
    website_session_id   INT            NOT NULL,
    pageview_url         NVARCHAR(255)  NOT NULL,

    CONSTRAINT PK_website_pageviews  PRIMARY KEY (website_pageview_id),
    CONSTRAINT FK_pageviews_sessions FOREIGN KEY (website_session_id)
        REFERENCES website_sessions (website_session_id)
);
GO

-- ============================================================
-- TABLE: orders
-- ============================================================
CREATE TABLE orders (
    order_id            INT             NOT NULL,
    created_at          DATETIME2       NOT NULL,
    website_session_id  INT             NOT NULL,
    user_id             INT             NOT NULL,
    primary_product_id  INT             NOT NULL,
    items_purchased     TINYINT         NOT NULL DEFAULT 1,
    price_usd           DECIMAL(8, 2)   NOT NULL,
    cogs_usd            DECIMAL(8, 2)   NOT NULL,

    CONSTRAINT PK_orders             PRIMARY KEY (order_id),
    CONSTRAINT FK_orders_sessions    FOREIGN KEY (website_session_id)
        REFERENCES website_sessions (website_session_id),
    CONSTRAINT FK_orders_products    FOREIGN KEY (primary_product_id)
        REFERENCES products (product_id)
);
GO

-- ============================================================
-- TABLE: order_items
-- ============================================================
CREATE TABLE order_items (
    order_item_id    INT            NOT NULL,
    created_at       DATETIME2      NOT NULL,
    order_id         INT            NOT NULL,
    product_id       INT            NOT NULL,
    is_primary_item  TINYINT        NOT NULL DEFAULT 0,  -- 1 = primary, 0 = cross-sell
    price_usd        DECIMAL(8, 2)  NOT NULL,
    cogs_usd         DECIMAL(8, 2)  NOT NULL,

    CONSTRAINT PK_order_items          PRIMARY KEY (order_item_id),
    CONSTRAINT FK_order_items_orders   FOREIGN KEY (order_id)
        REFERENCES orders (order_id),
    CONSTRAINT FK_order_items_products FOREIGN KEY (product_id)
        REFERENCES products (product_id)
);
GO

-- ============================================================
-- TABLE: order_item_refunds
-- ============================================================
CREATE TABLE order_item_refunds (
    order_item_refund_id  INT            NOT NULL,
    created_at            DATETIME2      NOT NULL,
    order_item_id         INT            NOT NULL,
    order_id              INT            NOT NULL,
    refund_amount_usd     DECIMAL(8, 2)  NOT NULL,

    CONSTRAINT PK_order_item_refunds        PRIMARY KEY (order_item_refund_id),
    CONSTRAINT FK_refunds_order_items       FOREIGN KEY (order_item_id)
        REFERENCES order_items (order_item_id),
    CONSTRAINT FK_refunds_orders            FOREIGN KEY (order_id)
        REFERENCES orders (order_id)
);
GO

-- ============================================================
-- INDEXES (hỗ trợ tăng tốc các query phân tích phổ biến)
-- ============================================================

-- Tìm sessions theo thời gian (trend analysis)
CREATE NONCLUSTERED INDEX IX_sessions_created_at
    ON website_sessions (created_at);
GO

-- Join pageviews → sessions nhanh hơn
CREATE NONCLUSTERED INDEX IX_pageviews_session_id
    ON website_pageviews (website_session_id);
GO

-- Join orders → sessions
CREATE NONCLUSTERED INDEX IX_orders_session_id
    ON orders (website_session_id);
GO

-- Tìm orders theo thời gian (revenue trend)
CREATE NONCLUSTERED INDEX IX_orders_created_at
    ON orders (created_at);
GO

-- Join order_items → orders
CREATE NONCLUSTERED INDEX IX_order_items_order_id
    ON order_items (order_id);
GO

-- Join refunds → order_items
CREATE NONCLUSTERED INDEX IX_refunds_order_item_id
    ON order_item_refunds (order_item_id);
GO

-- ============================================================
-- VERIFY: kiểm tra các bảng đã tạo
-- ============================================================
SELECT
    t.name          AS table_name,
    c.name          AS column_name,
    tp.name         AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.tables      t
JOIN sys.columns     c  ON t.object_id = c.object_id
JOIN sys.types       tp ON c.user_type_id = tp.user_type_id
ORDER BY t.name, c.column_id;
GO
