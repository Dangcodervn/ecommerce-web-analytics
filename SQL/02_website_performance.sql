-- ============================================================
-- 02_website_performance.sql
-- Landing page analysis, bounce rate, and top pages
-- ============================================================

-- 1. Identify landing page (first pageview) per session
CREATE TEMPORARY TABLE IF NOT EXISTS first_pageviews AS
SELECT
    website_session_id,
    MIN(website_pageview_id) AS first_pv_id
FROM website_pageviews
GROUP BY website_session_id;

-- 2. Map first pageview to URL
CREATE TEMPORARY TABLE IF NOT EXISTS landing_pages AS
SELECT
    fp.website_session_id,
    wp.pageview_url AS landing_page
FROM first_pageviews fp
JOIN website_pageviews wp
    ON fp.first_pv_id = wp.website_pageview_id;

-- 3. Bounce rate by landing page
--    (bounce = session with only 1 pageview)
SELECT
    lp.landing_page,
    COUNT(DISTINCT lp.website_session_id)                       AS sessions,
    COUNT(DISTINCT CASE WHEN pv_count.pv = 1
          THEN lp.website_session_id END)                       AS bounced_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN pv_count.pv = 1
          THEN lp.website_session_id END) * 100.0
        / COUNT(DISTINCT lp.website_session_id), 2)             AS bounce_rate_pct
FROM landing_pages lp
JOIN (
    SELECT website_session_id, COUNT(*) AS pv
    FROM website_pageviews
    GROUP BY website_session_id
) pv_count ON lp.website_session_id = pv_count.website_session_id
GROUP BY lp.landing_page
ORDER BY sessions DESC;

-- 4. Top 10 most visited pages
SELECT
    pageview_url,
    COUNT(*) AS pageviews
FROM website_pageviews
GROUP BY pageview_url
ORDER BY pageviews DESC
LIMIT 10;

-- 5. Desktop vs. Mobile bounce rate
SELECT
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id)                       AS sessions,
    COUNT(DISTINCT CASE WHEN pv_count.pv = 1
          THEN ws.website_session_id END)                       AS bounced_sessions,
    ROUND(COUNT(DISTINCT CASE WHEN pv_count.pv = 1
          THEN ws.website_session_id END) * 100.0
        / COUNT(DISTINCT ws.website_session_id), 2)             AS bounce_rate_pct
FROM website_sessions ws
JOIN (
    SELECT website_session_id, COUNT(*) AS pv
    FROM website_pageviews
    GROUP BY website_session_id
) pv_count ON ws.website_session_id = pv_count.website_session_id
GROUP BY ws.device_type;
