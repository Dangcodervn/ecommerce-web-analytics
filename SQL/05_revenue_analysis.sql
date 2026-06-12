-- ============================================================
-- 05_revenue_analysis.sql
-- Revenue trends, refund impact, and channel revenue
-- ============================================================

-- 1. Monthly revenue, orders, and average order value (AOV)
SELECT
    YEAR(created_at)    AS yr,
    MONTH(created_at)   AS mo,
    COUNT(DISTINCT order_id)          AS orders,
    ROUND(SUM(price_usd), 2)          AS revenue,
    ROUND(SUM(cogs_usd), 2)           AS cost,
    ROUND(SUM(price_usd) - SUM(cogs_usd), 2)      AS gross_profit,
    ROUND(AVG(price_usd), 2)          AS avg_order_value
FROM orders
GROUP BY yr, mo
ORDER BY yr, mo;

-- 2. Revenue by traffic source/channel
SELECT
    ws.utm_source,
    ws.utm_medium,
    COUNT(DISTINCT o.order_id)         AS orders,
    ROUND(SUM(o.price_usd), 2)         AS revenue,
    ROUND(AVG(o.price_usd), 2)         AS aov
FROM website_sessions ws
LEFT JOIN orders o ON ws.website_session_id = o.website_session_id
WHERE o.order_id IS NOT NULL
GROUP BY ws.utm_source, ws.utm_medium
ORDER BY revenue DESC;

-- 3. Refund impact on revenue
SELECT
    YEAR(o.created_at)   AS yr,
    MONTH(o.created_at)  AS mo,
    COUNT(DISTINCT o.order_id)                        AS orders,
    ROUND(SUM(o.price_usd), 2)                        AS gross_revenue,
    COUNT(DISTINCT oir.order_item_refund_id)           AS refunds,
    ROUND(SUM(oir.refund_amount_usd), 2)               AS refund_amount,
    ROUND(SUM(o.price_usd)
        - COALESCE(SUM(oir.refund_amount_usd), 0), 2) AS net_revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
GROUP BY yr, mo
ORDER BY yr, mo;

-- 4. Revenue by device type
SELECT
    ws.device_type,
    COUNT(DISTINCT o.order_id)    AS orders,
    ROUND(SUM(o.price_usd), 2)    AS revenue,
    ROUND(AVG(o.price_usd), 2)    AS aov
FROM website_sessions ws
JOIN orders o ON ws.website_session_id = o.website_session_id
GROUP BY ws.device_type
ORDER BY revenue DESC;

-- 5. Year-over-year growth
SELECT
    YEAR(created_at)              AS yr,
    COUNT(DISTINCT order_id)      AS total_orders,
    ROUND(SUM(price_usd), 2)      AS total_revenue,
    ROUND(SUM(price_usd) - SUM(cogs_usd), 2) AS gross_profit
FROM orders
GROUP BY yr
ORDER BY yr;
