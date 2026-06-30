-- Q1: Tổng session + order
-- Em cho anh tổng số session, tổng số đơn hàng, và conversion rate (đơn / session). 3 con số cho daily snapshot.
SELECT
	CAST(s.created_at AS DATE) AS snapshot_date,
	COUNT(*) AS total_sessions,
	COUNT(order_id) AS total_orders,
	CAST (ROUND( 100.0 * COUNT(o.order_id) / COUNT(*), 2) AS DECIMAL(5,2)) AS conversion_rate_pct
FROM [xomdata_dataset].[web_analytics].[website_sessions] s
LEFT JOIN [xomdata_dataset].[web_analytics].[orders] o ON o.website_session_id = s.website_session_id
GROUP BY CAST(s.created_at AS DATE)
ORDER BY snapshot_date;

-- Q2: Session theo UTM source
-- Chị cần số session theo từng utm_source — để thấy kênh nào đang bring traffic. Sắp giảm dần.
SELECT
	ISNULL(utm_source, 'other') AS utm_source,
	COUNT(*) AS total_sessions
FROM [xomdata_dataset].[web_analytics].[website_sessions]
GROUP BY utm_source
ORDER BY total_sessions DESC;

-- Q3: Device type distribution
-- Anh cần % session theo device type (desktop, mobile, tablet). Để đánh giá ưu tiên responsive design.
SELECT
	device_type,
	COUNT(*) AS device_total_sessions,
	CAST (ROUND( 100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS DECIMAL(5,2)) AS device_session_pct
FROM [xomdata_dataset].[web_analytics].[website_sessions]
GROUP BY device_type;

-- Q4: Top 10 URL nhiều pageview
-- Chị cần top 10 URL có nhiều pageview nhất — landing page nào đang hot?
SELECT TOP 10
      pageview_url,
	  COUNT(*) AS pageview_count
FROM [xomdata_dataset].[web_analytics].[website_pageviews]
GROUP BY pageview_url
ORDER BY pageview_count DESC;

-- Q5: Tổng doanh thu và COGS
-- Em cho anh tổng doanh thu + tổng COGS + margin. Để CFO nhanh daily check.
WITH tmp AS (
	SELECT
		CAST( o.created_at AS DATE) AS snapshot_date,
		SUM( CASE WHEN order_item_refund_id IS NULL THEN i.price_usd ELSE 0 END) AS net_revenue,
		SUM( CASE WHEN order_item_refund_id IS NULL THEN i.cogs_usd ELSE 0 END) AS total_cogs
	FROM [xomdata_dataset].[web_analytics].[orders] o
	LEFT JOIN [xomdata_dataset].[web_analytics].[order_items] i ON o.order_id = i.order_id
	LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
	GROUP BY CAST(o.created_at AS DATE)
)
SELECT
	*,
	CAST ( ROUND( 100.0 * (net_revenue - total_cogs) / NULLIF(net_revenue, 0) ,2 ) AS DECIMAL(5, 2)) AS gross_margin_pct
FROM tmp
ORDER BY snapshot_date;


-- Q6: Conversion rate theo UTM source
-- Chị cần conversion rate mỗi utm_source — source nào mang người đến mà nhiều người mua?
SELECT
	ISNULL( utm_source, 'other') AS utm_source, 
	COUNT( DISTINCT s.website_session_id) AS total_sessions,
	COUNT( DISTINCT o.order_id) AS total_orders,
	CAST( COUNT(DISTINCT o.order_id) * 1.0 *100 / COUNT(DISTINCT s.website_session_id) AS DECIMAL( 5, 2)) AS conversion_rate
FROM [xomdata_dataset].[web_analytics].[website_sessions] s
LEFT JOIN [xomdata_dataset].[web_analytics].[orders] o ON s.website_session_id = o.website_session_id
GROUP BY utm_source
ORDER BY conversion_rate;


-- Q7: Refund rate theo sản phẩm
-- Anh nghi có sản phẩm bị refund nhiều. Em cho anh refund rate mỗi sản phẩm (số item refund / số item sold). Quality team cần follow up sản phẩm có rate cao.
SELECT
	p.product_name,
	COUNT( r.order_item_refund_id) AS total_refund_items,
	COUNT( i.order_item_id) AS total_sold_items,
	CAST(COUNT(r.order_item_refund_id) * 100.0 / NULLIF(COUNT(i.order_item_id), 0) AS DECIMAL(5,2)) AS refund_rate_pct
FROM [xomdata_dataset].[web_analytics].[products] p
LEFT JOIN [xomdata_dataset].[web_analytics].[order_items] i ON p.product_id = i.product_id
LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
GROUP BY p.product_name
ORDER BY total_refund_items DESC;

-- Q8: Funnel URL sequence
-- Chị cần số session pass qua full funnel: homepage → product → cart → checkout → thank-you. Đếm session hit mỗi step.
WITH tmp AS (
	SELECT
		website_session_id,
		MAX(CASE WHEN pageview_url IN ('/home', '/lander-1', '/lander-2', '/lander-3', '/lander-4', '/lander-5') THEN 1 ELSE 0 END) AS reached_homepage,
		MAX(CASE WHEN pageview_url IN ('/products','/the-original-mr-fuzzy','/the-forever-love-bear', '/the-birthday-sugar-panda','/the-hudson-river-mini-bear') THEN 1 ELSE 0 END) AS reached_product,
		MAX(CASE WHEN pageview_url IN ('/cart') THEN 1 ELSE 0 END) AS reached_cart,
		MAX(CASE WHEN pageview_url IN ('/shipping', '/billing', '/billing-2') THEN 1 ELSE 0 END) AS reached_checkout,
		MAX(CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS reached_thankyou
	FROM [xomdata_dataset].[web_analytics].[website_pageviews]
	GROUP BY website_session_id
)
SELECT
	SUM(reached_homepage) AS homepage_sessions,
	SUM(reached_product) AS product_sessions,
	SUM(reached_cart) AS cart_sessions,
	SUM(reached_checkout) AS checkout_sessions,
	SUM(reached_thankyou) AS thankyou_sessioons
FROM tmp


SELECT DISTINCT pageview_url
FROM [xomdata_dataset].[web_analytics].[website_pageviews];

-- Q9: Doanh thu theo device
-- Anh cần tổng doanh thu theo device type — để biết device nào mang tiền nhiều.
WITH tmp AS (
    SELECT
        o.website_session_id,
        COUNT(i.order_item_id) AS total_sold_items,
        COUNT(r.order_item_refund_id) AS total_refund_items,
        SUM(CASE WHEN r.order_item_refund_id IS NULL THEN i.price_usd ELSE 0 END) AS order_value
    FROM [xomdata_dataset].[web_analytics].[orders] o
    LEFT JOIN [xomdata_dataset].[web_analytics].[order_items] i ON o.order_id = i.order_id
    LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
    GROUP BY o.website_session_id
)
SELECT
    s.device_type,
    SUM(tmp.order_value) AS net_revenue
FROM [xomdata_dataset].[web_analytics].[website_sessions] s
LEFT JOIN tmp ON s.website_session_id = tmp.website_session_id
GROUP BY s.device_type;

-- Q10: Campaign đóng góp khách quay lại
-- Chị cần số session repeat theo utm_campaign + số unique user — campaign nào hiệu quả retention?
WITH acquisition AS (
    SELECT
        user_id,
        ISNULL(utm_campaign, 'other') AS acquisition_campaign
    FROM [xomdata_dataset].[web_analytics].[website_sessions]
    WHERE is_repeat_session = 0
),
retained_users AS (
    SELECT
        user_id,
        SUM(CASE WHEN is_repeat_session = 1 THEN 1 ELSE 0 END) AS repeat_session_count
    FROM [xomdata_dataset].[web_analytics].[website_sessions]
    GROUP BY user_id
)
SELECT
    a.acquisition_campaign,
    COUNT(DISTINCT a.user_id) AS unique_users_acquired,
    SUM(CASE WHEN r.repeat_session_count > 0 THEN 1 ELSE 0 END) AS users_retained,
    SUM(r.repeat_session_count) AS total_repeat_sessions,
    CAST(SUM(CASE WHEN r.repeat_session_count > 0 THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(DISTINCT a.user_id), 0) AS DECIMAL(5,2)) AS retention_rate_pct
FROM acquisition a
JOIN retained_users r ON a.user_id = r.user_id
GROUP BY a.acquisition_campaign
ORDER BY retention_rate_pct DESC;

-- Q11: Thời gian trên page (sessionization)
-- Em tính giúp anh thời gian khách ở mỗi trang trước khi click trang kế. Flag page khách ở quá 30 phút (có thể abandoned).
WITH tmp AS (
	SELECT
		*,
		LEAD(pageview_url) OVER ( PARTITION BY website_session_id ORDER BY created_at) AS next_page,
		DATEDIFF(MINUTE, created_at, LEAD(created_at) OVER ( PARTITION BY website_session_id ORDER BY created_at)) AS minutes_on_this_page
	FROM [xomdata_dataset].[web_analytics].[website_pageviews]
)
SELECT
	website_pageview_id,
	pageview_url,
	next_page,
	minutes_on_this_page,
	CASE WHEN minutes_on_this_page > 30 THEN 1 ELSE 0 END AS abandoned
FROM tmp
WHERE pageview_url NOT IN ('/home', '/lander-1', '/lander-2', '/lander-3', '/lander-4', '/lander-5');

--Q12: First-touch vs last-touch attribution
--Chị cần so sánh attribution first-touch vs last-touch — mỗi user, source đầu tiên họ vào + source cuối trước khi mua. Giúp CMO quyết định budget model.
WITH tmp AS (
    SELECT
        s.user_id,
        ISNULL(s.utm_source, 'other') AS utm_source,
        ROW_NUMBER() OVER (PARTITION BY s.user_id ORDER BY s.created_at DESC) AS order_rank
    FROM [xomdata_dataset].[web_analytics].[website_sessions] s
    LEFT JOIN [xomdata_dataset].[web_analytics].[orders] o ON s.website_session_id = o.website_session_id
    WHERE order_id IS NOT NULL
),
last_touch_lists AS (
    SELECT user_id, utm_source
    FROM tmp
    WHERE order_rank = 1
),
first_touch_list AS (
    SELECT
        s.user_id,
        ISNULL(s.utm_source, 'other') AS utm_source
    FROM [xomdata_dataset].[web_analytics].[website_sessions] s
    WHERE s.is_repeat_session = 0
),
user_attribution AS (
    SELECT
        f.user_id,
        f.utm_source AS first_touch_source,
        l.utm_source AS last_touch_source,
        CASE WHEN f.utm_source = l.utm_source THEN 1 ELSE 0 END AS is_same_source
    FROM first_touch_list f
    JOIN last_touch_lists l ON f.user_id = l.user_id
)
SELECT 'first_touch' AS attribution_model, first_touch_source AS source, COUNT(*) AS users
FROM user_attribution
GROUP BY first_touch_source

UNION ALL

SELECT 'last_touch' AS attribution_model, last_touch_source AS source, COUNT(*) AS users
FROM user_attribution
GROUP BY last_touch_source

ORDER BY attribution_model, users DESC;

-- Q13: Cohort LTV theo first-session month
-- Anh cần cohort retention + LTV theo tháng user first session. 3 tháng kế tiếp họ spend bao nhiêu?
WITH tmp AS (
    SELECT
        s.user_id,
        s.created_at AS first_session_date,
        DATEFROMPARTS(YEAR(s.created_at), MONTH(s.created_at), 1) AS cohort_month
    FROM [xomdata_dataset].[web_analytics].[website_sessions] s
    WHERE s.is_repeat_session = 0
),
order_net AS (
    SELECT
        i.order_id,
        SUM(CASE WHEN r.order_item_refund_id IS NULL THEN i.price_usd ELSE 0 END) AS net_revenue
    FROM [xomdata_dataset].[web_analytics].[order_items] i
    LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
    GROUP BY i.order_id
),
order_level AS (
    SELECT
        o.order_id,
        o.user_id,
        tmp.cohort_month,
        DATEDIFF(DAY, tmp.first_session_date, o.created_at) AS days_since_first_session,
        CASE WHEN DATEDIFF(DAY, tmp.first_session_date, o.created_at) <= 30 THEN onv.net_revenue ELSE 0 END AS revenue_30,
        CASE WHEN DATEDIFF(DAY, tmp.first_session_date, o.created_at) <= 60 THEN onv.net_revenue ELSE 0 END AS revenue_60,
        CASE WHEN DATEDIFF(DAY, tmp.first_session_date, o.created_at) <= 90 THEN onv.net_revenue ELSE 0 END AS revenue_90
    FROM [xomdata_dataset].[web_analytics].[orders] o
    LEFT JOIN tmp ON tmp.user_id = o.user_id
    LEFT JOIN order_net onv ON onv.order_id = o.order_id
),
user_level AS (
    SELECT
        user_id,
        SUM(revenue_30) AS user_revenue_30,
        SUM(revenue_60) AS user_revenue_60,
        SUM(revenue_90) AS user_revenue_90
    FROM order_level
    GROUP BY user_id
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT user_id) AS total_users
    FROM tmp
    GROUP BY cohort_month
)
SELECT
    cs.cohort_month,
    cs.total_users,
    SUM(ISNULL(ul.user_revenue_30, 0)) AS net_revenue_30,
    SUM(ISNULL(ul.user_revenue_60, 0)) AS net_revenue_60,
    SUM(ISNULL(ul.user_revenue_90, 0)) AS net_revenue_90,
    SUM(ISNULL(ul.user_revenue_30, 0)) / cs.total_users AS net_ltv_30,
    SUM(ISNULL(ul.user_revenue_60, 0)) / cs.total_users AS net_ltv_60,
    SUM(ISNULL(ul.user_revenue_90, 0)) / cs.total_users AS net_ltv_90
FROM cohort_size cs
LEFT JOIN tmp t ON t.cohort_month = cs.cohort_month
LEFT JOIN user_level ul ON ul.user_id = t.user_id
GROUP BY cs.cohort_month, cs.total_users
ORDER BY cs.cohort_month;

-- Q14: Rolling 28 ngày doanh thu
--  Chị cần doanh thu daily + rolling 28d average — để thấy trend smooth không bị daily noise.
WITH tmp AS (
	SELECT
		CAST( o.created_at AS DATE) AS snapshot_date,
		SUM( CASE WHEN order_item_refund_id IS NULL THEN i.price_usd ELSE 0 END) AS net_revenue
	FROM [xomdata_dataset].[web_analytics].[orders] o
	LEFT JOIN [xomdata_dataset].[web_analytics].[order_items] i ON o.order_id = i.order_id
	LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
	GROUP BY CAST(o.created_at AS DATE)
)
SELECT
    snapshot_date,
    net_revenue,
    AVG(net_revenue) OVER (ORDER BY snapshot_date ROWS BETWEEN 27 PRECEDING AND CURRENT ROW) AS rolling_28d_average
FROM tmp
ORDER BY snapshot_date;

-- Q15: Net revenue theo product (trừ refund)
-- Em cho anh net revenue mỗi sản phẩm = doanh thu - refund. Rank theo net, để biết sản phẩm nào thực sự đóng góp.
WITH tmp AS (
    SELECT
	    p.product_name,
	    SUM(CASE WHEN r.order_item_refund_id IS NULL THEN i.price_usd ELSE 0 END) AS net_revenue_by_product
    FROM [xomdata_dataset].[web_analytics].[products] p
    LEFT JOIN [xomdata_dataset].[web_analytics].[order_items] i ON p.product_id = i.product_id
    LEFT JOIN [xomdata_dataset].[web_analytics].[order_item_refunds] r ON i.order_item_id = r.order_item_id
    GROUP BY p.product_name
)
SELECT
    *,
    CAST(net_revenue_by_product * 100.0 / SUM(net_revenue_by_product) OVER () AS DECIMAL(5,2)) AS pct_of_total,
    RANK() OVER (ORDER BY net_revenue_by_product DESC) AS product_revenue_rank
FROM tmp