-- ============================================================
-- 01_traffic_analysis.sql
-- Analyze traffic sources, channels, and session trends
-- ============================================================

-- 1. Sessions by traffic source (UTM source + medium)
SELECT
    utm_source,
    utm_medium,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
GROUP BY utm_source, utm_medium
ORDER BY sessions DESC;

-- 2. Paid vs. Organic traffic breakdown
SELECT
    CASE
        WHEN utm_medium = 'cpc' THEN 'Paid Search'
        WHEN utm_medium = 'organic' THEN 'Organic Search'
        WHEN utm_medium IS NULL AND http_referer IS NULL THEN 'Direct'
        WHEN utm_medium IS NULL AND http_referer IS NOT NULL THEN 'Organic / Referral'
        ELSE 'Other'
    END AS channel,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
GROUP BY channel
ORDER BY sessions DESC;

-- 3. Monthly session trend
SELECT
    YEAR(created_at)  AS yr,
    MONTH(created_at) AS mo,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
GROUP BY yr, mo
ORDER BY yr, mo;

-- 4. Sessions by device type
SELECT
    device_type,
    COUNT(DISTINCT website_session_id) AS sessions
FROM website_sessions
GROUP BY device_type
ORDER BY sessions DESC;

-- 5. Sessions and orders by traffic source (conversion rate)
SELECT
    ws.utm_source,
    ws.utm_medium,
    COUNT(DISTINCT ws.website_session_id)  AS sessions,
    COUNT(DISTINCT o.order_id)             AS orders,
    ROUND(COUNT(DISTINCT o.order_id) * 100.0
        / COUNT(DISTINCT ws.website_session_id), 2) AS cvr_pct
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.utm_source, ws.utm_medium
ORDER BY sessions DESC;
