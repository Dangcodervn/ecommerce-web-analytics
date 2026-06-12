-- ============================================================
-- 03_conversion_funnel.sql
-- Step-by-step conversion funnel from landing to order
-- ============================================================

-- Funnel pages (adjust URLs to match your dataset)
-- /home → /products → /product-detail → /cart → /shipping → /billing → /thank-you

-- 1. Flag each session for funnel steps
SELECT
    ws.website_session_id,
    MAX(CASE WHEN wp.pageview_url = '/home'           THEN 1 ELSE 0 END) AS saw_home,
    MAX(CASE WHEN wp.pageview_url = '/products'       THEN 1 ELSE 0 END) AS saw_products,
    MAX(CASE WHEN wp.pageview_url LIKE '/the-original-mr-fuzzy'
                                                      THEN 1 ELSE 0 END) AS saw_product_detail,
    MAX(CASE WHEN wp.pageview_url = '/cart'           THEN 1 ELSE 0 END) AS saw_cart,
    MAX(CASE WHEN wp.pageview_url = '/shipping'       THEN 1 ELSE 0 END) AS saw_shipping,
    MAX(CASE WHEN wp.pageview_url = '/billing'        THEN 1 ELSE 0 END) AS saw_billing,
    MAX(CASE WHEN wp.pageview_url = '/thank-you-for-your-order'
                                                      THEN 1 ELSE 0 END) AS saw_thankyou
FROM website_sessions ws
JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
GROUP BY ws.website_session_id;

-- 2. Funnel summary (aggregate step counts)
-- Wrap the above as a CTE for cleaner reporting:
WITH funnel AS (
    SELECT
        ws.website_session_id,
        MAX(CASE WHEN wp.pageview_url = '/home'           THEN 1 ELSE 0 END) AS saw_home,
        MAX(CASE WHEN wp.pageview_url = '/products'       THEN 1 ELSE 0 END) AS saw_products,
        MAX(CASE WHEN wp.pageview_url LIKE '/the-original-mr-fuzzy'
                                                          THEN 1 ELSE 0 END) AS saw_product_detail,
        MAX(CASE WHEN wp.pageview_url = '/cart'           THEN 1 ELSE 0 END) AS saw_cart,
        MAX(CASE WHEN wp.pageview_url = '/shipping'       THEN 1 ELSE 0 END) AS saw_shipping,
        MAX(CASE WHEN wp.pageview_url = '/billing'        THEN 1 ELSE 0 END) AS saw_billing,
        MAX(CASE WHEN wp.pageview_url = '/thank-you-for-your-order'
                                                          THEN 1 ELSE 0 END) AS saw_thankyou
    FROM website_sessions ws
    JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY ws.website_session_id
)
SELECT
    SUM(saw_home)           AS lander,
    SUM(saw_products)       AS products_page,
    SUM(saw_product_detail) AS product_detail,
    SUM(saw_cart)           AS cart,
    SUM(saw_shipping)       AS shipping,
    SUM(saw_billing)        AS billing,
    SUM(saw_thankyou)       AS orders
FROM funnel;

-- 3. Funnel click-through rate at each step
WITH funnel AS (
    SELECT
        ws.website_session_id,
        MAX(CASE WHEN wp.pageview_url = '/home'           THEN 1 ELSE 0 END) AS saw_home,
        MAX(CASE WHEN wp.pageview_url = '/products'       THEN 1 ELSE 0 END) AS saw_products,
        MAX(CASE WHEN wp.pageview_url LIKE '/the-original-mr-fuzzy'
                                                          THEN 1 ELSE 0 END) AS saw_product_detail,
        MAX(CASE WHEN wp.pageview_url = '/cart'           THEN 1 ELSE 0 END) AS saw_cart,
        MAX(CASE WHEN wp.pageview_url = '/shipping'       THEN 1 ELSE 0 END) AS saw_shipping,
        MAX(CASE WHEN wp.pageview_url = '/billing'        THEN 1 ELSE 0 END) AS saw_billing,
        MAX(CASE WHEN wp.pageview_url = '/thank-you-for-your-order'
                                                          THEN 1 ELSE 0 END) AS saw_thankyou
    FROM website_sessions ws
    JOIN website_pageviews wp ON ws.website_session_id = wp.website_session_id
    GROUP BY ws.website_session_id
),
totals AS (
    SELECT
        SUM(saw_home)           AS lander,
        SUM(saw_products)       AS products_page,
        SUM(saw_product_detail) AS product_detail,
        SUM(saw_cart)           AS cart,
        SUM(saw_shipping)       AS shipping,
        SUM(saw_billing)        AS billing,
        SUM(saw_thankyou)       AS orders
    FROM funnel
)
SELECT
    lander,
    ROUND(products_page  * 100.0 / lander,         2) AS lander_to_products_pct,
    ROUND(product_detail * 100.0 / products_page,  2) AS products_to_detail_pct,
    ROUND(cart           * 100.0 / product_detail, 2) AS detail_to_cart_pct,
    ROUND(shipping       * 100.0 / cart,           2) AS cart_to_shipping_pct,
    ROUND(billing        * 100.0 / shipping,       2) AS shipping_to_billing_pct,
    ROUND(orders         * 100.0 / billing,        2) AS billing_to_order_pct
FROM totals;
