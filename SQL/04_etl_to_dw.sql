-- 04_etl_to_dw.sql
-- ETL staging → dw: dims trước (1-4), facts sau (5-6)

USE ecommerce_web_analytics;
GO

-- Step 1: dim_date — sinh calendar 2012–2015
TRUNCATE TABLE dw.dim_date;
GO

WITH date_seq AS (
    SELECT CAST('2012-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM date_seq WHERE d < '2015-12-31'
)
INSERT INTO dw.dim_date (
    date_key, full_date, year, quarter, month, month_name,
    week_of_year, day_of_month, day_of_week, day_name, is_weekend
)
SELECT
    CONVERT(INT, FORMAT(d, 'yyyyMMdd'))                              AS date_key,
    d                                                                 AS full_date,
    YEAR(d)                                                           AS year,
    DATEPART(QUARTER, d)                                              AS quarter,
    MONTH(d)                                                          AS month,
    DATENAME(MONTH, d)                                                AS month_name,
    DATEPART(WEEK, d)                                                 AS week_of_year,
    DAY(d)                                                            AS day_of_month,
    DATEPART(WEEKDAY, d)                                              AS day_of_week,
    DATENAME(WEEKDAY, d)                                              AS day_name,
    CASE WHEN DATEPART(WEEKDAY, d) IN (1,7) THEN 1 ELSE 0 END        AS is_weekend
FROM date_seq
OPTION (MAXRECURSION 2000);
GO
SELECT 'dw.dim_date' AS table_name, COUNT(*) AS row_count FROM dw.dim_date;
GO

-- Step 2: dim_product
TRUNCATE TABLE dw.dim_product;
GO

INSERT INTO dw.dim_product (product_id, product_name, launch_date)
SELECT
    product_id,
    product_name,
    CAST(created_at AS DATE) AS launch_date
FROM staging.products;
GO
SELECT 'dw.dim_product' AS table_name, COUNT(*) AS row_count FROM dw.dim_product;
GO

-- Step 3: dim_device
TRUNCATE TABLE dw.dim_device;
GO

INSERT INTO dw.dim_device (device_type)
SELECT DISTINCT device_type
FROM staging.website_sessions;
GO
SELECT 'dw.dim_device' AS table_name, COUNT(*) AS row_count FROM dw.dim_device;
GO

-- Step 4: dim_channel — derived từ utm_source + http_referer
TRUNCATE TABLE dw.dim_channel;
GO

INSERT INTO dw.dim_channel (utm_source, utm_campaign, channel_group)
SELECT DISTINCT
    utm_source,
    utm_campaign,
    CASE
        WHEN utm_source = 'gsearch'                             THEN 'Paid Search - Google'
        WHEN utm_source = 'bsearch'                             THEN 'Paid Search - Bing'
        WHEN utm_source IS NULL AND http_referer LIKE '%gsearch%' THEN 'Organic Search'
        WHEN utm_source IS NULL AND http_referer IS NOT NULL    THEN 'Organic / Referral'
        WHEN utm_source IS NULL AND http_referer IS NULL        THEN 'Direct'
        ELSE 'Other'
    END AS channel_group
FROM staging.website_sessions;
GO
SELECT 'dw.dim_channel' AS table_name, COUNT(*) AS row_count FROM dw.dim_channel;
GO

-- Step 5: fact_sessions (grain: 1 row/session)
TRUNCATE TABLE dw.fact_sessions;
GO

INSERT INTO dw.fact_sessions (
    date_key, channel_key, device_key,
    website_session_id, user_id, is_repeat_session,
    pageview_count, is_bounce, converted_to_order
)
SELECT
    CONVERT(INT, FORMAT(CAST(ws.created_at AS DATE), 'yyyyMMdd'))    AS date_key,
    dc.channel_key,
    dd.device_key,
    ws.website_session_id,
    ws.user_id,
    ws.is_repeat_session,
    pv.pageview_count,
    CASE WHEN pv.pageview_count = 1          THEN 1 ELSE 0 END       AS is_bounce,
    CASE WHEN o.website_session_id IS NOT NULL THEN 1 ELSE 0 END     AS converted_to_order
FROM staging.website_sessions ws
JOIN dw.dim_channel dc
    ON ISNULL(ws.utm_source,    '<<NULL>>') = ISNULL(dc.utm_source,    '<<NULL>>')
    AND ISNULL(ws.utm_campaign, '<<NULL>>') = ISNULL(dc.utm_campaign,  '<<NULL>>')
JOIN dw.dim_device dd
    ON ws.device_type = dd.device_type
JOIN (
    SELECT website_session_id, COUNT(*) AS pageview_count
    FROM staging.website_pageviews
    GROUP BY website_session_id
) pv ON ws.website_session_id = pv.website_session_id
LEFT JOIN (
    SELECT DISTINCT website_session_id
    FROM staging.orders
) o ON ws.website_session_id = o.website_session_id;
GO
SELECT 'dw.fact_sessions' AS table_name, COUNT(*) AS row_count FROM dw.fact_sessions;
GO

-- Step 6: fact_orders (grain: 1 row/order_item, bao gồm refund)
TRUNCATE TABLE dw.fact_orders;
GO

INSERT INTO dw.fact_orders (
    date_key, product_key, channel_key, device_key,
    order_id, order_item_id, website_session_id, user_id,
    is_primary_item, is_repeat_session, items_purchased,
    price_usd, cogs_usd, gross_profit_usd,
    refund_amount_usd, is_refunded
)
SELECT
    CONVERT(INT, FORMAT(CAST(o.created_at AS DATE), 'yyyyMMdd'))     AS date_key,
    dp.product_key,
    dc.channel_key,
    dd.device_key,
    oi.order_id,
    oi.order_item_id,
    o.website_session_id,
    o.user_id,
    oi.is_primary_item,
    ws.is_repeat_session,
    o.items_purchased,
    oi.price_usd,
    oi.cogs_usd,
    oi.price_usd - oi.cogs_usd                                       AS gross_profit_usd,
    ISNULL(r.refund_amount_usd, 0)                                    AS refund_amount_usd,
    CASE WHEN r.order_item_refund_id IS NOT NULL THEN 1 ELSE 0 END   AS is_refunded
FROM staging.order_items oi
JOIN staging.orders           o  ON oi.order_id           = o.order_id
JOIN staging.website_sessions ws ON o.website_session_id  = ws.website_session_id
JOIN dw.dim_product           dp ON oi.product_id         = dp.product_id
JOIN dw.dim_channel           dc
    ON ISNULL(ws.utm_source,    '<<NULL>>') = ISNULL(dc.utm_source,    '<<NULL>>')
    AND ISNULL(ws.utm_campaign, '<<NULL>>') = ISNULL(dc.utm_campaign,  '<<NULL>>')
JOIN dw.dim_device            dd ON ws.device_type        = dd.device_type
LEFT JOIN staging.order_item_refunds r ON oi.order_item_id = r.order_item_id;
GO
SELECT 'dw.fact_orders' AS table_name, COUNT(*) AS row_count FROM dw.fact_orders;
GO

-- Summary
SELECT tbl, rows FROM (
    SELECT 'dw.dim_date'      AS tbl, COUNT(*) AS rows FROM dw.dim_date      UNION ALL
    SELECT 'dw.dim_product',                               COUNT(*) FROM dw.dim_product UNION ALL
    SELECT 'dw.dim_device',                                COUNT(*) FROM dw.dim_device  UNION ALL
    SELECT 'dw.dim_channel',                               COUNT(*) FROM dw.dim_channel UNION ALL
    SELECT 'dw.fact_sessions',                             COUNT(*) FROM dw.fact_sessions UNION ALL
    SELECT 'dw.fact_orders',                               COUNT(*) FROM dw.fact_orders
) summary;
GO
