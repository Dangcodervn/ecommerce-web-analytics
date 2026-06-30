-- 03_create_dw.sql
-- Galaxy Schema (nhiều fact dùng chung conformed dims)
-- Thiết kế theo FACT-first: mỗi business process = 1 fact ở 1 grain rõ ràng.
--
-- NGUYÊN TẮC THIẾT KẾ:
--   - Mỗi attribute CHỈ sống ở 1 grain duy nhất (nguồn gốc của nó).
--   - Grain thấp hơn chỉ giữ bridge key để nối lên, không lặp lại attribute.
--   - date_key: ngoại lệ hợp lệ - mỗi event có timestamp riêng.
--
-- DIMENSIONS (3, conformed):
--   dim_date    : lịch 2012-2015
--   dim_product : sản phẩm (4 sản phẩm, giá cố định)
--   dim_channel : junk dimension marketing → channel_group, is_paid
--
-- FACTS (4) và GRAIN:
--   fact_sessions    : 1 row / session      → channel, device, user sống ĐÂY
--   fact_pageviews   : 1 row / pageview     → bridge qua website_session_id
--   fact_orders      : 1 row / order header → bridge qua website_session_id
--   fact_order_items : 1 row / order line   → bridge qua order_id; product sống ĐÂY
--
-- KHÔNG trùng lặp:
--   channel_key  → CHỈ fact_sessions
--   device_type  → CHỈ fact_sessions
--   user_id      → CHỈ fact_sessions
--   product_key  → CHỈ fact_order_items
--   date_key     → mỗi fact có timestamp riêng (OK)

USE ecommerce_web_analytics;
GO

-- Dọn sạch nếu chạy lại
IF OBJECT_ID('dw.v_session_channel')  IS NOT NULL DROP VIEW  dw.v_session_channel;
IF OBJECT_ID('dw.fact_order_items')   IS NOT NULL DROP TABLE dw.fact_order_items;
IF OBJECT_ID('dw.fact_orders')        IS NOT NULL DROP TABLE dw.fact_orders;
IF OBJECT_ID('dw.fact_pageviews')     IS NOT NULL DROP TABLE dw.fact_pageviews;
IF OBJECT_ID('dw.fact_sessions')      IS NOT NULL DROP TABLE dw.fact_sessions;
IF OBJECT_ID('dw.dim_channel')        IS NOT NULL DROP TABLE dw.dim_channel;
IF OBJECT_ID('dw.dim_product')        IS NOT NULL DROP TABLE dw.dim_product;
IF OBJECT_ID('dw.dim_date')           IS NOT NULL DROP TABLE dw.dim_date;
GO

IF SCHEMA_ID('dw') IS NULL EXEC('CREATE SCHEMA dw');
GO

-- ============================================================
-- DIMENSIONS
-- ============================================================

-- dim_date: date_key dạng YYYYMMDD (vd 20120319)
CREATE TABLE dw.dim_date (
    date_key      INT           NOT NULL,
    full_date     DATE          NOT NULL,
    year          SMALLINT      NOT NULL,
    quarter       TINYINT       NOT NULL,
    month         TINYINT       NOT NULL,
    month_name    NVARCHAR(10)  NOT NULL,
    year_month    INT           NOT NULL,        -- 201203, tiện sort trục thời gian
    week_of_year  TINYINT       NOT NULL,
    day_of_month  TINYINT       NOT NULL,
    day_of_week   TINYINT       NOT NULL,        -- 1=Sun … 7=Sat
    day_name      NVARCHAR(10)  NOT NULL,
    is_weekend    BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_date PRIMARY KEY (date_key)
);
GO

-- dim_product: SK = product_key (IDENTITY), NK = product_id
-- price_usd/cogs_usd = giá niêm yết tham chiếu (cố định trong dataset)
CREATE TABLE dw.dim_product (
    product_key  INT            NOT NULL IDENTITY(1,1),
    product_id   INT            NOT NULL,
    product_name NVARCHAR(100)  NOT NULL,
    launch_date  DATE           NOT NULL,
    price_usd    DECIMAL(8,2)   NOT NULL,
    cogs_usd     DECIMAL(8,2)   NOT NULL,
    margin_usd   DECIMAL(8,2)   NOT NULL,
    CONSTRAINT PK_dim_product    PRIMARY KEY (product_key),
    CONSTRAINT UQ_dim_product_id UNIQUE      (product_id)
);
GO

-- dim_channel: junk dimension. 1 dòng / tổ hợp (utm_source, utm_campaign, channel_group)
-- channel_group derived. is_paid = traffic trả tiền hay không.
CREATE TABLE dw.dim_channel (
    channel_key   INT           NOT NULL IDENTITY(1,1),
    utm_source    NVARCHAR(50)  NULL,
    utm_campaign  NVARCHAR(50)  NULL,
    channel_group NVARCHAR(50)  NOT NULL,
    is_paid       BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_dim_channel PRIMARY KEY (channel_key)
);
GO

-- ============================================================
-- FACTS
-- ============================================================

-- fact_sessions: grain = 1 session
-- channel, device, user sống ĐÂY - không lặp xuống fact khác
CREATE TABLE dw.fact_sessions (
    session_key          INT          NOT NULL IDENTITY(1,1),
    date_key             INT          NOT NULL,
    channel_key          INT          NOT NULL,
    website_session_id   INT          NOT NULL,
    user_id              INT          NOT NULL,
    device_type          NVARCHAR(20) NOT NULL,
    is_repeat_session    TINYINT      NOT NULL,
    -- measures
    pageview_count       INT          NOT NULL DEFAULT 0,
    session_duration_sec INT          NOT NULL DEFAULT 0,
    is_bounce            BIT          NOT NULL DEFAULT 0,
    is_converted         BIT          NOT NULL DEFAULT 0,
    CONSTRAINT PK_fact_sessions    PRIMARY KEY (session_key),
    CONSTRAINT UQ_fact_sessions_nk UNIQUE      (website_session_id),
    CONSTRAINT FK_fs_date          FOREIGN KEY (date_key)    REFERENCES dw.dim_date    (date_key),
    CONSTRAINT FK_fs_channel       FOREIGN KEY (channel_key) REFERENCES dw.dim_channel (channel_key)
);
GO

-- fact_pageviews: grain = 1 pageview (~1.5M dòng)
-- channel, device, user KHÔNG lưu ở đây → lấy từ fact_sessions qua website_session_id
CREATE TABLE dw.fact_pageviews (
    pageview_key        INT            NOT NULL IDENTITY(1,1),
    date_key            INT            NOT NULL,
    website_session_id  INT            NOT NULL,   -- bridge → fact_sessions
    website_pageview_id INT            NOT NULL,
    pageview_url        NVARCHAR(255)  NOT NULL,
    -- measures
    pageview_number     INT            NOT NULL,
    is_entry_page       BIT            NOT NULL DEFAULT 0,
    is_exit_page        BIT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_fact_pageviews   PRIMARY KEY (pageview_key),
    CONSTRAINT UQ_fact_pageviews   UNIQUE      (website_pageview_id),
    CONSTRAINT FK_fpv_date         FOREIGN KEY (date_key) REFERENCES dw.dim_date (date_key)
);
GO

-- fact_orders: grain = 1 order header
-- channel, device, user KHÔNG lưu ở đây → lấy từ fact_sessions qua website_session_id
-- product KHÔNG lưu ở đây → sống ở fact_order_items (grain thấp hơn)
CREATE TABLE dw.fact_orders (
    order_key              INT           NOT NULL IDENTITY(1,1),
    date_key               INT           NOT NULL,
    website_session_id     INT           NOT NULL,   -- bridge → fact_sessions
    order_id               INT           NOT NULL,
    -- measures
    items_purchased        TINYINT       NOT NULL DEFAULT 1,
    order_revenue_usd      DECIMAL(10,2) NOT NULL,
    order_cogs_usd         DECIMAL(10,2) NOT NULL,
    order_gross_profit_usd DECIMAL(10,2) NOT NULL,
    refund_amount_usd      DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_refunded            BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_fact_orders    PRIMARY KEY (order_key),
    CONSTRAINT UQ_fact_orders_nk UNIQUE      (order_id),
    CONSTRAINT FK_fo_date        FOREIGN KEY (date_key) REFERENCES dw.dim_date (date_key)
);
GO

-- fact_order_items: grain = 1 order_item line
-- channel, device, user KHÔNG lưu ở đây → lấy qua order_id → fact_orders → fact_sessions
-- product sống ĐÂY (grain này là nơi duy nhất biết sản phẩm nào trong đơn)
CREATE TABLE dw.fact_order_items (
    order_item_key    INT            NOT NULL IDENTITY(1,1),
    date_key          INT            NOT NULL,
    product_key       INT            NOT NULL,
    order_id          INT            NOT NULL,   -- bridge → fact_orders
    order_item_id     INT            NOT NULL,
    is_primary_item   TINYINT        NOT NULL,
    -- measures
    quantity          INT            NOT NULL DEFAULT 1,
    price_usd         DECIMAL(8,2)   NOT NULL,
    cogs_usd          DECIMAL(8,2)   NOT NULL,
    gross_profit_usd  DECIMAL(8,2)   NOT NULL,
    refund_amount_usd DECIMAL(8,2)   NOT NULL DEFAULT 0,
    is_refunded       BIT            NOT NULL DEFAULT 0,
    CONSTRAINT PK_fact_order_items    PRIMARY KEY (order_item_key),
    CONSTRAINT UQ_fact_order_items_nk UNIQUE      (order_item_id),
    CONSTRAINT FK_foi_date            FOREIGN KEY (date_key)    REFERENCES dw.dim_date    (date_key),
    CONSTRAINT FK_foi_product         FOREIGN KEY (product_key) REFERENCES dw.dim_product (product_key),
    CONSTRAINT FK_foi_order           FOREIGN KEY (order_id)    REFERENCES dw.fact_orders (order_id)
);
GO

-- ============================================================
-- INDEXES
-- ============================================================
CREATE NONCLUSTERED INDEX IX_fs_date     ON dw.fact_sessions    (date_key);
CREATE NONCLUSTERED INDEX IX_fs_channel  ON dw.fact_sessions    (channel_key);

CREATE NONCLUSTERED INDEX IX_fpv_date    ON dw.fact_pageviews   (date_key);
CREATE NONCLUSTERED INDEX IX_fpv_session ON dw.fact_pageviews   (website_session_id);
CREATE NONCLUSTERED INDEX IX_fpv_url     ON dw.fact_pageviews   (pageview_url);

CREATE NONCLUSTERED INDEX IX_fo_date     ON dw.fact_orders      (date_key);
CREATE NONCLUSTERED INDEX IX_fo_session  ON dw.fact_orders      (website_session_id);

CREATE NONCLUSTERED INDEX IX_foi_date    ON dw.fact_order_items (date_key);
CREATE NONCLUSTERED INDEX IX_foi_product ON dw.fact_order_items (product_key);
CREATE NONCLUSTERED INDEX IX_foi_order   ON dw.fact_order_items (order_id);
GO

-- Kiểm tra
SELECT s.name AS schema_name, t.name AS table_name
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name IN ('staging', 'dw')
ORDER BY s.name, t.name;
GO
