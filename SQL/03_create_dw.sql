-- 03_create_dw.sql
-- Tạo dw schema: 4 dimensions + 2 fact tables (Kimball Star Schema)

USE ecommerce_web_analytics;
GO

CREATE SCHEMA dw;
GO

-- dim_date: date_key dạng YYYYMMDD, ví dụ 20120319
CREATE TABLE dw.dim_date (
    date_key        INT           NOT NULL,
    full_date       DATE          NOT NULL,
    year            SMALLINT      NOT NULL,
    quarter         TINYINT       NOT NULL,   -- 1–4
    month           TINYINT       NOT NULL,   -- 1–12
    month_name      NVARCHAR(10)  NOT NULL,
    week_of_year    TINYINT       NOT NULL,
    day_of_month    TINYINT       NOT NULL,
    day_of_week     TINYINT       NOT NULL,   -- 1=Sun … 7=Sat (SQL Server default)
    day_name        NVARCHAR(10)  NOT NULL,
    is_weekend      BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);
GO

-- dim_product: product_key = surrogate (IDENTITY), product_id = natural key
CREATE TABLE dw.dim_product (
    product_key  INT            NOT NULL IDENTITY(1,1),
    product_id   INT            NOT NULL,
    product_name NVARCHAR(100)  NOT NULL,
    launch_date  DATE           NOT NULL,
    CONSTRAINT PK_dim_product    PRIMARY KEY (product_key),
    CONSTRAINT UQ_dim_product_id UNIQUE      (product_id)
);
GO

-- dim_device
CREATE TABLE dw.dim_device (
    device_key  INT          NOT NULL IDENTITY(1,1),
    device_type NVARCHAR(20) NOT NULL,   -- 'desktop' | 'mobile'
    CONSTRAINT PK_dim_device PRIMARY KEY (device_key)
);
GO

-- dim_channel: derived từ utm_source + utm_campaign
-- channel_group: 'Paid Search - Google/Bing', 'Organic Search', 'Organic / Referral', 'Direct', 'Other'
CREATE TABLE dw.dim_channel (
    channel_key   INT           NOT NULL IDENTITY(1,1),
    utm_source    NVARCHAR(50)  NULL,
    utm_campaign  NVARCHAR(50)  NULL,
    channel_group NVARCHAR(50)  NOT NULL,
    CONSTRAINT PK_dim_channel PRIMARY KEY (channel_key)
);
GO

-- fact_sessions: grain = 1 row per session
CREATE TABLE dw.fact_sessions (
    fact_session_key    INT    NOT NULL IDENTITY(1,1),

    -- Surrogate keys → dims
    date_key            INT    NOT NULL,
    channel_key         INT    NOT NULL,
    device_key          INT    NOT NULL,

    -- Degenerate dimensions
    website_session_id  INT    NOT NULL,
    user_id             INT    NOT NULL,
    is_repeat_session   TINYINT NOT NULL,

    -- Measures
    pageview_count      INT    NOT NULL DEFAULT 0,
    is_bounce           BIT    NOT NULL DEFAULT 0,   -- 1 nếu chỉ xem 1 trang
    converted_to_order  BIT    NOT NULL DEFAULT 0,   -- 1 nếu có đơn hàng

    CONSTRAINT PK_fact_sessions  PRIMARY KEY (fact_session_key),
    CONSTRAINT FK_fs_date        FOREIGN KEY (date_key)    REFERENCES dw.dim_date    (date_key),
    CONSTRAINT FK_fs_channel     FOREIGN KEY (channel_key) REFERENCES dw.dim_channel (channel_key),
    CONSTRAINT FK_fs_device      FOREIGN KEY (device_key)  REFERENCES dw.dim_device  (device_key)
);
GO

-- fact_orders: grain = 1 row per order_item
CREATE TABLE dw.fact_orders (
    fact_order_key      INT            NOT NULL IDENTITY(1,1),

    -- Surrogate keys → dims
    date_key            INT            NOT NULL,
    product_key         INT            NOT NULL,
    channel_key         INT            NOT NULL,
    device_key          INT            NOT NULL,

    -- Degenerate dimensions
    order_id            INT            NOT NULL,
    order_item_id       INT            NOT NULL,
    website_session_id  INT            NOT NULL,
    user_id             INT            NOT NULL,
    is_primary_item     TINYINT        NOT NULL,
    is_repeat_session   TINYINT        NOT NULL,
    items_purchased     TINYINT        NOT NULL DEFAULT 1,

    -- Measures
    price_usd           DECIMAL(8,2)   NOT NULL,
    cogs_usd            DECIMAL(8,2)   NOT NULL,
    gross_profit_usd    DECIMAL(8,2)   NOT NULL,   -- price - cogs
    refund_amount_usd   DECIMAL(8,2)   NOT NULL DEFAULT 0,
    is_refunded         BIT            NOT NULL DEFAULT 0,

    CONSTRAINT PK_fact_orders   PRIMARY KEY (fact_order_key),
    CONSTRAINT FK_fo_date       FOREIGN KEY (date_key)    REFERENCES dw.dim_date    (date_key),
    CONSTRAINT FK_fo_product    FOREIGN KEY (product_key) REFERENCES dw.dim_product (product_key),
    CONSTRAINT FK_fo_channel    FOREIGN KEY (channel_key) REFERENCES dw.dim_channel (channel_key),
    CONSTRAINT FK_fo_device     FOREIGN KEY (device_key)  REFERENCES dw.dim_device  (device_key)
);
GO

-- Indexes trên fact tables
CREATE NONCLUSTERED INDEX IX_fact_sessions_date     ON dw.fact_sessions (date_key);
CREATE NONCLUSTERED INDEX IX_fact_sessions_channel  ON dw.fact_sessions (channel_key);
CREATE NONCLUSTERED INDEX IX_fact_sessions_device   ON dw.fact_sessions (device_key);
CREATE NONCLUSTERED INDEX IX_fact_orders_date       ON dw.fact_orders   (date_key);
CREATE NONCLUSTERED INDEX IX_fact_orders_product    ON dw.fact_orders   (product_key);
CREATE NONCLUSTERED INDEX IX_fact_orders_channel    ON dw.fact_orders   (channel_key);
GO

-- Kiểm tra
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('staging', 'dw')
ORDER BY s.name, t.name;
GO
