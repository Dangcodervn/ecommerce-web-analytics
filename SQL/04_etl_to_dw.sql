-- 04_etl_to_dw.sql
-- ETL staging -> dw
-- Thứ tự: dims trước (1-3) → helper view (4) → facts (5-8)
-- fact_orders nạp trước fact_order_items vì có FK order_id

USE ecommerce_web_analytics;
GO

-- ============================================================
-- Step 1: dim_date — calendar 2012-2015
-- ============================================================
DELETE FROM dw.dim_date;
GO

WITH date_seq AS (
    SELECT CAST('2012-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM date_seq WHERE d < '2015-12-31'
)
INSERT INTO dw.dim_date (
    date_key, full_date, year, quarter, month, month_name, year_month,
    week_of_year, day_of_month, day_of_week, day_name, is_weekend
)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd')),
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    YEAR(d) * 100 + MONTH(d),
    DATEPART(WEEK, d),
    DAY(d),
    DATEPART(WEEKDAY, d),
    DATENAME(WEEKDAY, d),
    CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 1 ELSE 0 END
FROM date_seq
OPTION (MAXRECURSION 2000);
GO
SELECT 'dw.dim_date' AS table_name, COUNT(*) AS row_count FROM dw.dim_date;
GO

-- ============================================================
-- Step 2: dim_product
-- price/cogs lấy từ order_items (MIN = MAX vì giá cố định)
-- ============================================================
DELETE FROM dw.dim_product;
DBCC CHECKIDENT ('dw.dim_product', RESEED, 0);
GO

INSERT INTO dw.dim_product (product_id, product_name, launch_date, price_usd, cogs_usd, margin_usd)
SELECT
    p.product_id,
    p.product_name,
    CAST(p.created_at AS DATE),
    oi.price_usd,
    oi.cogs_usd,
    oi.price_usd - oi.cogs_usd
FROM staging.products p
JOIN (
    SELECT product_id, MIN(price_usd) AS price_usd, MIN(cogs_usd) AS cogs_usd
    FROM staging.order_items
    GROUP BY product_id
) oi ON p.product_id = oi.product_id;
GO
SELECT 'dw.dim_product' AS table_name, COUNT(*) AS row_count FROM dw.dim_product;
GO

-- ============================================================
-- Step 3: dim_channel
-- ============================================================
DELETE FROM dw.dim_channel;
DBCC CHECKIDENT ('dw.dim_channel', RESEED, 0);
GO

INSERT INTO dw.dim_channel (utm_source, utm_campaign, channel_group, is_paid)
SELECT DISTINCT
    utm_source,
    utm_campaign,
    CASE
        WHEN utm_source = 'gsearch'    THEN 'Paid Search - Google'
        WHEN utm_source = 'bsearch'    THEN 'Paid Search - Bing'
        WHEN utm_source = 'socialbook' THEN 'Paid Social'
        WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN 'Organic / Referral'
        WHEN utm_source IS NULL AND http_referer IS NULL     THEN 'Direct'
        ELSE 'Other'
    END,
    CASE WHEN utm_source IN ('gsearch','bsearch','socialbook') THEN 1 ELSE 0 END
FROM staging.website_sessions;
GO
SELECT 'dw.dim_channel' AS table_name, COUNT(*) AS row_count FROM dw.dim_channel;
GO

-- ============================================================
-- Step 4: view ánh xạ session → channel_key (chỉ dùng cho fact_sessions)
-- ============================================================
IF OBJECT_ID('dw.v_session_channel') IS NOT NULL DROP VIEW dw.v_session_channel;
GO
CREATE VIEW dw.v_session_channel AS
SELECT
    ws.website_session_id,
    dc.channel_key
FROM staging.website_sessions ws
JOIN dw.dim_channel dc
    ON  ISNULL(ws.utm_source,   '<<N>>') = ISNULL(dc.utm_source,   '<<N>>')
    AND ISNULL(ws.utm_campaign, '<<N>>') = ISNULL(dc.utm_campaign, '<<N>>')
    AND dc.channel_group =
        CASE
            WHEN ws.utm_source = 'gsearch'    THEN 'Paid Search - Google'
            WHEN ws.utm_source = 'bsearch'    THEN 'Paid Search - Bing'
            WHEN ws.utm_source = 'socialbook' THEN 'Paid Social'
            WHEN ws.utm_source IS NULL AND ws.http_referer IS NOT NULL THEN 'Organic / Referral'
            WHEN ws.utm_source IS NULL AND ws.http_referer IS NULL     THEN 'Direct'
            ELSE 'Other'
        END;
GO

-- ============================================================
-- Step 5: fact_sessions (grain = 1 session)
-- ============================================================
DELETE FROM dw.fact_sessions;
DBCC CHECKIDENT ('dw.fact_sessions', RESEED, 0);
GO

INSERT INTO dw.fact_sessions (
    date_key, channel_key, website_session_id, user_id, device_type, is_repeat_session,
    pageview_count, session_duration_sec, is_bounce, is_converted
)
SELECT
    CONVERT(INT, FORMAT(CAST(ws.created_at AS DATE), 'yyyyMMdd')),
    sc.channel_key,
    ws.website_session_id,
    ws.user_id,
    ws.device_type,
    ws.is_repeat_session,
    ISNULL(pv.pageview_count, 0),
    ISNULL(pv.duration_sec, 0),
    CASE WHEN ISNULL(pv.pageview_count, 0) = 1 THEN 1 ELSE 0 END,
    CASE WHEN o.website_session_id IS NOT NULL  THEN 1 ELSE 0 END
FROM staging.website_sessions ws
JOIN dw.v_session_channel sc ON ws.website_session_id = sc.website_session_id
LEFT JOIN (
    SELECT website_session_id,
           COUNT(*) AS pageview_count,
           DATEDIFF(SECOND, MIN(created_at), MAX(created_at)) AS duration_sec
    FROM staging.website_pageviews
    GROUP BY website_session_id
) pv ON ws.website_session_id = pv.website_session_id
LEFT JOIN (
    SELECT DISTINCT website_session_id FROM staging.orders
) o ON ws.website_session_id = o.website_session_id;
GO
SELECT 'dw.fact_sessions' AS table_name, COUNT(*) AS row_count FROM dw.fact_sessions;
GO

-- ============================================================
-- Step 6: fact_pageviews (grain = 1 pageview)
-- Không JOIN session — channel/device không còn ở đây
-- ============================================================
DELETE FROM dw.fact_pageviews;
DBCC CHECKIDENT ('dw.fact_pageviews', RESEED, 0);
GO

WITH pv_seq AS (
    SELECT
        website_pageview_id,
        website_session_id,
        created_at,
        pageview_url,
        ROW_NUMBER() OVER (PARTITION BY website_session_id ORDER BY website_pageview_id) AS pageview_number,
        COUNT(*)     OVER (PARTITION BY website_session_id)                               AS total_pv
    FROM staging.website_pageviews
)
INSERT INTO dw.fact_pageviews (
    date_key, website_session_id, website_pageview_id,
    pageview_url, pageview_number, is_entry_page, is_exit_page
)
SELECT
    CONVERT(INT, FORMAT(CAST(pv.created_at AS DATE), 'yyyyMMdd')),
    pv.website_session_id,
    pv.website_pageview_id,
    pv.pageview_url,
    pv.pageview_number,
    CASE WHEN pv.pageview_number = 1           THEN 1 ELSE 0 END,
    CASE WHEN pv.pageview_number = pv.total_pv THEN 1 ELSE 0 END
FROM pv_seq pv;
GO
SELECT 'dw.fact_pageviews' AS table_name, COUNT(*) AS row_count FROM dw.fact_pageviews;
GO

-- ============================================================
-- Step 7: fact_orders (grain = 1 order header)
-- Chỉ đọc staging.orders + refunds — không JOIN session/product
-- ============================================================
DELETE FROM dw.fact_orders;
DBCC CHECKIDENT ('dw.fact_orders', RESEED, 0);
GO

INSERT INTO dw.fact_orders (
    date_key, website_session_id, order_id,
    items_purchased, order_revenue_usd, order_cogs_usd, order_gross_profit_usd,
    refund_amount_usd, is_refunded
)
SELECT
    CONVERT(INT, FORMAT(CAST(o.created_at AS DATE), 'yyyyMMdd')),
    o.website_session_id,
    o.order_id,
    o.items_purchased,
    o.price_usd,
    o.cogs_usd,
    o.price_usd - o.cogs_usd,
    ISNULL(r.refund_amount_usd, 0),
    CASE WHEN r.refund_amount_usd > 0 THEN 1 ELSE 0 END
FROM staging.orders o
LEFT JOIN (
    SELECT order_id, SUM(refund_amount_usd) AS refund_amount_usd
    FROM staging.order_item_refunds
    GROUP BY order_id
) r ON o.order_id = r.order_id;
GO
SELECT 'dw.fact_orders' AS table_name, COUNT(*) AS row_count FROM dw.fact_orders;
GO

-- ============================================================
-- Step 8: fact_order_items (grain = 1 order_item line)
-- Chỉ JOIN dim_product + refunds — không JOIN session/channel
-- ============================================================
DELETE FROM dw.fact_order_items;
DBCC CHECKIDENT ('dw.fact_order_items', RESEED, 0);
GO

INSERT INTO dw.fact_order_items (
    date_key, product_key, order_id, order_item_id, is_primary_item,
    quantity, price_usd, cogs_usd, gross_profit_usd, refund_amount_usd, is_refunded
)
SELECT
    CONVERT(INT, FORMAT(CAST(oi.created_at AS DATE), 'yyyyMMdd')),
    dp.product_key,
    oi.order_id,
    oi.order_item_id,
    oi.is_primary_item,
    1,
    oi.price_usd,
    oi.cogs_usd,
    oi.price_usd - oi.cogs_usd,
    ISNULL(r.refund_amount_usd, 0),
    CASE WHEN r.refund_amount_usd > 0 THEN 1 ELSE 0 END
FROM staging.order_items oi
JOIN dw.dim_product dp ON oi.product_id = dp.product_id
LEFT JOIN (
    SELECT order_item_id, SUM(refund_amount_usd) AS refund_amount_usd
    FROM staging.order_item_refunds
    GROUP BY order_item_id
) r ON oi.order_item_id = r.order_item_id;
GO
SELECT 'dw.fact_order_items' AS table_name, COUNT(*) AS row_count FROM dw.fact_order_items;
GO

-- ============================================================
-- Summary + kiểm tra nhất quán revenue giữa 2 grain
-- ============================================================
SELECT tbl, [rows] FROM (
    SELECT 'dw.dim_date'         AS tbl, COUNT(*) AS [rows] FROM dw.dim_date         UNION ALL
    SELECT 'dw.dim_product',                  COUNT(*) FROM dw.dim_product            UNION ALL
    SELECT 'dw.dim_channel',                  COUNT(*) FROM dw.dim_channel            UNION ALL
    SELECT 'dw.fact_sessions',                COUNT(*) FROM dw.fact_sessions          UNION ALL
    SELECT 'dw.fact_pageviews',               COUNT(*) FROM dw.fact_pageviews         UNION ALL
    SELECT 'dw.fact_orders',                  COUNT(*) FROM dw.fact_orders            UNION ALL
    SELECT 'dw.fact_order_items',             COUNT(*) FROM dw.fact_order_items
) s;
GO

-- Đối chiếu: header revenue = line revenue; header item count = line row count
SELECT
    (SELECT SUM(order_revenue_usd) FROM dw.fact_orders)      AS header_revenue,
    (SELECT SUM(price_usd)         FROM dw.fact_order_items) AS line_revenue,
    (SELECT SUM(items_purchased)   FROM dw.fact_orders)      AS header_item_count,
    (SELECT COUNT(*)               FROM dw.fact_order_items) AS line_row_count;
GO
