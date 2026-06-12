-- ============================================================
-- 04_product_analysis.sql
-- Product sales, revenue, and cross-sell analysis
-- ============================================================

-- 1. Overall product performance
SELECT
    p.product_name,
    COUNT(DISTINCT oi.order_id)       AS orders,
    SUM(oi.price_usd)                 AS revenue,
    SUM(oi.cogs_usd)                  AS cost,
    ROUND(SUM(oi.price_usd)
        - SUM(oi.cogs_usd), 2)        AS margin,
    ROUND((SUM(oi.price_usd) - SUM(oi.cogs_usd))
        * 100.0 / SUM(oi.price_usd), 2) AS margin_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY revenue DESC;

-- 2. Monthly product order trend
SELECT
    YEAR(o.created_at)  AS yr,
    MONTH(o.created_at) AS mo,
    p.product_name,
    COUNT(DISTINCT oi.order_id) AS orders,
    SUM(oi.price_usd)           AS revenue
FROM order_items oi
JOIN orders   o ON oi.order_id    = o.order_id
JOIN products p ON oi.product_id  = p.product_id
GROUP BY yr, mo, p.product_name
ORDER BY yr, mo, revenue DESC;

-- 3. Refund rate by product
SELECT
    p.product_name,
    COUNT(DISTINCT oi.order_item_id)                        AS items_sold,
    COUNT(DISTINCT oir.order_item_refund_id)                AS refunds,
    ROUND(COUNT(DISTINCT oir.order_item_refund_id) * 100.0
        / COUNT(DISTINCT oi.order_item_id), 2)              AS refund_rate_pct
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
GROUP BY p.product_name
ORDER BY refund_rate_pct DESC;

-- 4. Cross-sell analysis (which products are bought together)
SELECT
    p1.product_name   AS primary_product,
    p2.product_name   AS cross_sell_product,
    COUNT(*)          AS times_cross_sold
FROM order_items oi1
JOIN order_items oi2 ON oi1.order_id = oi2.order_id
    AND oi1.order_item_id <> oi2.order_item_id
    AND oi1.is_primary_item = 1
JOIN products p1 ON oi1.product_id = p1.product_id
JOIN products p2 ON oi2.product_id = p2.product_id
GROUP BY primary_product, cross_sell_product
ORDER BY times_cross_sold DESC;
