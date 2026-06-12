# Ecommerce Web Analytics

A data analytics project analyzing ecommerce business performance using SQL — covering traffic sources, website behavior, product performance, and revenue trends.

---

## Project Structure

```
ecommerce-web-analytics/
├── Data/                          # Raw datasets (CSV)
│   ├── orders.csv
│   ├── order_items.csv
│   ├── order_item_refunds.csv
│   ├── products.csv
│   ├── website_pageviews.csv
│   └── website_sessions.csv
├── SQL/
│   ├── 01_traffic_analysis.sql    # Traffic source & channel analysis
│   ├── 02_website_performance.sql # Bounce rate, landing page analysis
│   ├── 03_conversion_funnel.sql   # Conversion funnel analysis
│   ├── 04_product_analysis.sql    # Product sales & performance
│   └── 05_revenue_analysis.sql    # Revenue, refunds & business trends
└── README.md
```

---

## Dataset Overview

| Table | Description |
|---|---|
| `website_sessions` | User sessions with traffic source, UTM params, device type |
| `website_pageviews` | Pages viewed per session |
| `orders` | Order records linked to sessions |
| `order_items` | Individual items per order |
| `order_item_refunds` | Refund records |
| `products` | Product catalog |

---

## Analysis Areas

### 1. Traffic Analysis
- Top traffic sources and channels
- Paid vs. organic session breakdown
- Session trends over time

### 2. Website Performance
- Bounce rate by landing page
- Top entry and exit pages
- Device type comparison (desktop vs. mobile)

### 3. Conversion Funnel
- Step-by-step funnel from landing page to order
- Drop-off rates at each stage
- Funnel comparison across traffic sources

### 4. Product Analysis
- Best-selling products
- Revenue per product
- Cross-sell and product launch impact

### 5. Revenue Analysis
- Monthly revenue and order volume
- Refund rate and impact
- Revenue by traffic channel

---

## Tools Used

- **SQL** (MySQL / PostgreSQL)
- **Excel / Google Sheets** (optional: quick visualization)
- **Tableau / Power BI** (optional: dashboard)

---

## Key Business Questions Answered

1. Which traffic channels bring the most revenue?
2. Which landing pages convert best?
3. Where do users drop off in the conversion funnel?
4. Which products drive the most revenue?
5. How has the business grown over time?

---

## How to Use

1. Import all CSV files in `Data/` into your SQL database.
2. Run SQL scripts in `SQL/` folder in order (01 → 05).
3. Review results and build visualizations as needed.
