-- 02_data_validation.sql
-- Kiểm tra chất lượng dữ liệu trong staging
-- Check 1-4: kết quả = 0 → sạch | Check 5-7: thông tin phân phối

USE ecommerce_web_analytics;
GO

-- 1. NULL ở các cột quan trọng
SELECT 'sessions - website_session_id NULL'            AS check_name, COUNT(*) AS cnt
FROM staging.website_sessions WHERE website_session_id IS NULL
UNION ALL
SELECT 'sessions - created_at NULL',                                  COUNT(*)
FROM staging.website_sessions WHERE created_at IS NULL
UNION ALL
SELECT 'sessions - user_id NULL',                                     COUNT(*)
FROM staging.website_sessions WHERE user_id IS NULL
UNION ALL
SELECT 'sessions - is_repeat_session NULL',                           COUNT(*)
FROM staging.website_sessions WHERE is_repeat_session IS NULL
UNION ALL
SELECT 'sessions - device_type NULL',                                 COUNT(*)
FROM staging.website_sessions WHERE device_type IS NULL
UNION ALL
SELECT 'sessions - utm_source NULL (expected for direct/organic)',    COUNT(*)
FROM staging.website_sessions WHERE utm_source IS NULL
UNION ALL
SELECT 'sessions - utm_campaign NULL (expected sometimes)',           COUNT(*)
FROM staging.website_sessions WHERE utm_campaign IS NULL
UNION ALL
SELECT 'sessions - utm_content NULL (expected sometimes)',            COUNT(*)
FROM staging.website_sessions WHERE utm_content IS NULL
UNION ALL
SELECT 'sessions - http_referer NULL (expected for direct)',          COUNT(*)
FROM staging.website_sessions WHERE http_referer IS NULL
UNION ALL
SELECT 'sessions - utm_source literal ''NULL''',                      COUNT(*)
FROM staging.website_sessions WHERE utm_source = 'NULL'
UNION ALL
SELECT 'sessions - utm_campaign literal ''NULL''',                    COUNT(*)
FROM staging.website_sessions WHERE utm_campaign = 'NULL'
UNION ALL
SELECT 'sessions - utm_content literal ''NULL''',                     COUNT(*)
FROM staging.website_sessions WHERE utm_content = 'NULL'
UNION ALL
SELECT 'sessions - http_referer literal ''NULL''',                    COUNT(*)
FROM staging.website_sessions WHERE http_referer = 'NULL'
UNION ALL
SELECT 'orders - website_session_id NULL',                            COUNT(*)
FROM staging.orders WHERE website_session_id IS NULL
UNION ALL
SELECT 'order_items - order_id NULL',                                 COUNT(*)
FROM staging.order_items WHERE order_id IS NULL
UNION ALL
SELECT 'order_item_refunds - refund_amount NULL',                     COUNT(*)
FROM staging.order_item_refunds WHERE refund_amount_usd IS NULL;
GO

-- 2. Duplicate PK (mong đợi: tất cả = 0)
SELECT 'products duplicate PK'           AS check_name,
       COUNT(*) - COUNT(DISTINCT product_id)            AS duplicates
FROM staging.products
UNION ALL
SELECT 'website_sessions duplicate PK',
       COUNT(*) - COUNT(DISTINCT website_session_id)
FROM staging.website_sessions
UNION ALL
SELECT 'website_pageviews duplicate PK',
       COUNT(*) - COUNT(DISTINCT website_pageview_id)
FROM staging.website_pageviews
UNION ALL
SELECT 'orders duplicate PK',
       COUNT(*) - COUNT(DISTINCT order_id)
FROM staging.orders
UNION ALL
SELECT 'order_items duplicate PK',
       COUNT(*) - COUNT(DISTINCT order_item_id)
FROM staging.order_items
UNION ALL
SELECT 'order_item_refunds duplicate PK',
       COUNT(*) - COUNT(DISTINCT order_item_refund_id)
FROM staging.order_item_refunds;
GO

-- 3. FK orphan — bản ghi trỏ tới ID không tồn tại (mong đợi: tất cả = 0)
SELECT 'pageviews → sessions orphan'     AS check_name, COUNT(*) AS orphan_count
FROM staging.website_pageviews wp
WHERE NOT EXISTS (
    SELECT 1 FROM staging.website_sessions ws
    WHERE ws.website_session_id = wp.website_session_id)
UNION ALL
SELECT 'orders → sessions orphan',      COUNT(*)
FROM staging.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM staging.website_sessions ws
    WHERE ws.website_session_id = o.website_session_id)
UNION ALL
SELECT 'orders → products orphan',      COUNT(*)
FROM staging.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM staging.products p
    WHERE p.product_id = o.primary_product_id)
UNION ALL
SELECT 'order_items → orders orphan',   COUNT(*)
FROM staging.order_items oi
WHERE NOT EXISTS (
    SELECT 1 FROM staging.orders o
    WHERE o.order_id = oi.order_id)
UNION ALL
SELECT 'order_items → products orphan', COUNT(*)
FROM staging.order_items oi
WHERE NOT EXISTS (
    SELECT 1 FROM staging.products p
    WHERE p.product_id = oi.product_id)
UNION ALL
SELECT 'refunds → order_items orphan',  COUNT(*)
FROM staging.order_item_refunds r
WHERE NOT EXISTS (
    SELECT 1 FROM staging.order_items oi
    WHERE oi.order_item_id = r.order_item_id);
GO

-- 4. Giá trị bất thường — price/refund (mong đợi: tất cả = 0)
SELECT 'orders - price_usd <= 0'         AS check_name, COUNT(*) AS cnt
FROM staging.orders WHERE price_usd <= 0
UNION ALL
SELECT 'orders - cogs > price',           COUNT(*)
FROM staging.orders WHERE cogs_usd > price_usd
UNION ALL
SELECT 'order_items - price_usd <= 0',    COUNT(*)
FROM staging.order_items WHERE price_usd <= 0
UNION ALL
SELECT 'refunds - amount <= 0',           COUNT(*)
FROM staging.order_item_refunds WHERE refund_amount_usd <= 0
UNION ALL
SELECT 'refunds - amount > item price',   COUNT(*)
FROM staging.order_item_refunds r
JOIN staging.order_items oi ON r.order_item_id = oi.order_item_id
WHERE r.refund_amount_usd > oi.price_usd;
GO

-- 5. Phạm vi thời gian dữ liệu
SELECT
    'staging.website_sessions'  AS tbl,
    MIN(created_at)             AS earliest,
    MAX(created_at)             AS latest,
    DATEDIFF(DAY, MIN(created_at), MAX(created_at)) AS span_days
FROM staging.website_sessions
UNION ALL
SELECT 'staging.orders',
    MIN(created_at), MAX(created_at),
    DATEDIFF(DAY, MIN(created_at), MAX(created_at))
FROM staging.orders
UNION ALL
SELECT 'staging.order_item_refunds',
    MIN(created_at), MAX(created_at),
    DATEDIFF(DAY, MIN(created_at), MAX(created_at))
FROM staging.order_item_refunds;
GO

-- 6. Phân phối traffic source + device
SELECT
    ISNULL(utm_source, '(direct/organic)') AS utm_source,
    ISNULL(utm_campaign, '-')              AS utm_campaign,
    device_type,
    COUNT(*)                               AS sessions
FROM staging.website_sessions
GROUP BY utm_source, utm_campaign, device_type
ORDER BY sessions DESC;
GO

-- 7. Phân phối pageview URLs
SELECT
    pageview_url,
    COUNT(*) AS pageviews
FROM staging.website_pageviews
GROUP BY pageview_url
ORDER BY pageviews DESC;
GO

PRINT 'Validation done. Check 1-4: all 0 = clean. Check 5-7: info only.';
GO
