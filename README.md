# 🛒 Google Analytics Session Analysis | SQL

![SQL](https://img.shields.io/badge/Language-SQL-3776AB?style=flat-square&logo=sql&logoColor=white)
![Google BigQuery](https://img.shields.io/badge/Google_BigQuery-4285F4?style=flat-square&logo=googlebigquery&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success?style=flat-square)

---

<p align="center">
  <img src="Images/banner.png" width="100%">
</p>

_Analyze website traffic, user engagement, and purchase behavior to answer 8 business questions and turn raw analytics data into clear insights._

- 🎯 **Business Question:** Which traffic sources drive the most revenue - and how do user engagement patterns differ between purchasers and non-purchasers?
- 🏬 **Domain:** E-commerce & Digital Marketing
- 🛠️ **Tools:** SQL (Google BigQuery)

👤 **Author:** Bạch Minh Nam

---

## 📌 Overview

**Objective:**

- This project uses SQL (Google BigQuery) to analyze **Google Analytics 4 (GA4)** data from the **Google Merchandise Store** e-commerce website
- It answers 8 specific business questions covering **Traffic Performance, User Engagement, Revenue Analysis, and Conversion Funnel Optimization**
- The goal is to turn raw session and event data into clear, actionable insights for marketing and product teams

**Main business question:**

This project uses SQL to analyze website traffic, engagement, and revenue data from Google Analytics to:
- Track changes in visits, pageviews, and transactions over time
- Evaluate which traffic sources generate the most revenue and engagement
- Compare user behavior between purchasers and non-purchasers
- Identify cross-selling opportunities and conversion funnel bottlenecks

**👤 Who is this project for?**

- **Data analysts & business analysts** who want a reference for writing analytical SQL (CTEs, window functions, cohort analysis, UNNEST operations)
- **Digital marketing teams** who need insights into traffic source performance and ROI
- **E-commerce managers & stakeholders** who need quick insights into revenue trends, user engagement, and conversion rates
- **Business intelligence teams** building dashboards and reporting systems

### 📑 Table of Contents

- [📌 Overview](#-overview)
- [📂 Dataset](#-dataset)
- [🔎 Query Repository](#-query-repository)
- [🗂️ Project Structure](#️-project-structure)
- [🚀 Setup Instructions](#-setup-instructions)

---

## 📂 Dataset

The analysis is based on **Google Analytics 4 (GA4)** data exported to **Google BigQuery**, representing the **Google Merchandise Store**, a real e-commerce website selling branded merchandise. It contains data on user sessions, page views, product interactions, transactions, and revenue across multiple months in 2017.

### Data Dictionary

To answer the 8 business questions in this project, **6 core data structures** from the GA4 export schema were used. The table below lists only the columns that were actually used in the queries.

| Schema | Table / Struct | Columns Used | Used In | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Sessions** | `ga_sessions_2017*` | `date`, `fullVisitorId` | Q1, Q2, Q4, Q5, Q6, Q8 | Base session table tracking unique users and session timestamps for all temporal analysis. |
| **Sessions** | `totals` | `visits`, `pageviews`, `transactions`, `bounces` | Q1, Q2, Q4, Q5, Q6 | Aggregate metrics per session - visits, pageviews, bounce count, transaction count for KPI calculations. |
| **Sessions** | `trafficSource` | `source` | Q2, Q3 | Identifies traffic channel origin (organic search, direct, referral, paid ads) to analyze channel performance. |
| **Hits** | `hits` | `eCommerceAction` | Q8 | Unnested to capture individual user actions within a session (product view, add to cart, purchase). |
| **Hits** | `eCommerceAction` | `action_type` | Q8 | Action type codes (**'2'=View, '3'=Add to Cart, '6'=Purchase**) to build conversion funnel analysis. |
| **Product** | `product` | `v2ProductName`, `productRevenue`, `productQuantity` | Q3, Q4, Q6, Q7, Q8 | Unnested product-level data to track revenue, quantities sold, and product-specific insights. |

> 🔗 **Full Documentation:** For the complete explanation of all available fields in the GA4 BigQuery export schema, please refer to the [Official Google Analytics BigQuery Export schema](https://support.google.com/analytics/answer/3437719?hl=en).

---

## 🔎 Query Repository

### Query 1: Monthly Traffic Overview (Jan–Mar 2017)

*Question: Calculate total visits, pageviews, and transactions for January, February, and March 2017.*

> _Tracking monthly traffic metrics helps the business understand seasonal demand patterns and measure the impact of marketing campaigns across the first quarter._

```sql
SELECT 
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  COUNT(totals.visits) AS visits,
  SUM(totals.pageviews) AS pageviews,
  SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month
```

**📊 Actual Output:**
![Query 1 Output](Images/Query_1_Output.png)

**💡 Observations:**

Traffic and engagement show strong growth momentum across Q1 2017. **January (201701)** recorded 64,694 visits with 257,708 pageviews and 713 transactions, while **March (201703)** surged to 69,931 visits (+8.1%) with 259,522 pageviews and 993 transactions (+39.3%). The transaction spike in March suggests successful promotions or seasonal demand - this period warrants investigation into what marketing initiatives or product launches drove the conversion uplift.

---

### Query 2: Bounce Rate by Traffic Source (July 2017)

*Question: Calculate the bounce rate per traffic source in July 2017.*

> _High bounce rates indicate poor landing page relevance or user experience issues. Identifying which traffic sources bounce most helps prioritize optimization efforts and reallocate budget from underperforming channels._

```sql
SELECT
  trafficSource.source AS source,
  SUM(totals.visits) AS total_visits,
  SUM(totals.bounces) AS total_no_of_bounces,
  ROUND(SUM(totals.bounces) / SUM(totals.visits) * 100, 3) AS bounce_rate
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
GROUP BY source
ORDER BY total_visits DESC
```

**📊 Actual Output:**
![Query 2 Output](Images/Query_2_Output.png)

**💡 Observations:**

**Google** dominates traffic volume with 38,400 visits but carries a concerning **51.56% bounce rate** - meaning half of Google Search visitors leave without engaging. **(direct)** traffic shows better engagement with a **43.27% bounce rate** and 19,891 visits, indicating brand loyalty from repeat visitors. **YouTube.com** referrals have the highest bounce rate at **66.73%**, suggesting content mismatch or poor landing page experience. Priority should be given to improving landing page quality for high-volume, high-bounce sources like Google and YouTube to recover lost conversion opportunities.

---

### Query 3: Revenue by Traffic Source (June 2017 – Weekly & Monthly)

*Question: Calculate revenue by traffic source by week and by month in June 2017.*

> _Breaking revenue down by traffic source and time period reveals which channels are most profitable and when peak revenue occurs. This guides budget allocation and campaign timing decisions._

```sql
WITH month_data AS (
  SELECT
    'Month' AS time_type,
    FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
    trafficSource.source AS source,
    SUM(p.productRevenue) / 1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) AS hits,
    UNNEST(product) AS p
  WHERE p.productRevenue IS NOT NULL
  GROUP BY 1, 2, 3
),

week_data AS (
  SELECT
    'Week' AS time_type,
    FORMAT_DATE('%Y%W', PARSE_DATE('%Y%m%d', date)) AS week,
    trafficSource.source AS source,
    SUM(p.productRevenue) / 1000000 AS revenue
  FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201706*`,
    UNNEST(hits) AS hits,
    UNNEST(product) AS p
  WHERE p.productRevenue IS NOT NULL
  GROUP BY 1, 2, 3
)

SELECT * FROM month_data
UNION ALL
SELECT * FROM week_data
ORDER BY time_type, revenue DESC
```

**📊 Actual Output:**
![Query 3 Output](Images/Query_3_Output.png)

**💡 Observations:**

**(direct) traffic** is the **clear revenue champion** with **$97,333.62K in June** - far exceeding all other sources and proving that brand recognition and repeat customers are the largest revenue driver. **Google** ranks second with **$18,757.18K**, validating paid search investment. Weekly breakdown reveals revenue peaks around **Week 23–24**, suggesting mid-to-late June seasonal strength. Surprisingly, high-bounce channels like **YouTube.com** and **mail.google.com** generate negligible revenue (<$200K combined), confirming that bounce rate inversely correlates with conversion intent - these channels require urgent redesign or sunsetting from the media mix.

---

### Query 4: Avg Pageviews - Purchasers vs Non-Purchasers (Jun–Jul 2017)

*Question: Calculate average number of pageviews by purchaser type (purchasers vs non-purchasers) in June and July 2017.*

> _Comparing engagement between buyers and non-buyers reveals the page view threshold needed to drive conversion. Higher pageview counts among purchasers signal deeper product exploration before purchase._

```sql
WITH
  base AS (
    SELECT
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
      totals.transactions,
      product.productRevenue,
      totals.pageviews,
      fullVisitorId
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits) AS hits,
      UNNEST(product) AS product
    WHERE _table_suffix BETWEEN '0601' AND '0731'
  ),

  purchase AS (
    SELECT
      month,
      ROUND(SUM(pageviews) / COUNT(DISTINCT fullVisitorId), 8) AS avg_pageviews_purchase
    FROM base
    WHERE transactions >= 1 
      AND productRevenue IS NOT NULL
    GROUP BY month
  ),

  non_purchase AS (
    SELECT
      month,
      ROUND(SUM(pageviews) / COUNT(DISTINCT fullVisitorId), 8) AS avg_pageviews_non_purchase
    FROM base
    WHERE transactions IS NULL
      AND productRevenue IS NULL
    GROUP BY month
  )

SELECT *
FROM purchase
FULL JOIN non_purchase USING (month)
ORDER BY month
```

**📊 Actual Output:**
![Query 4 Output](Images/Query_4_Output.png)

**💡 Observations:**

A dramatic **engagement gap** exists between purchasers and non-purchasers. In **June (201706)**, purchasers averaged **94.02 pageviews** versus **316.87 for non-purchasers** - counterintuitively, browsers visit 3.4x more pages than buyers. This suggests two distinct user cohorts: **(1) Focused buyers** who know what they want and convert quickly, and **(2) Research-heavy browsers** who lack purchase intent. The July pattern repeats, with purchasers at **124.24 pageviews** vs non-purchasers at **334.06**. The implication: high pageview counts ≠ high conversion probability. Marketing should focus on intent signals (product page time, cart additions) rather than overall pageview volume when targeting high-value prospects.

---

### Query 5: Avg Transactions per Purchasing User (July 2017)

*Question: Calculate the average number of transactions per user that made a purchase in July 2017.*

> _Understanding repeat purchase frequency within a month reveals customer loyalty and multi-purchase behavior. Higher repeat rates indicate strong product satisfaction and cross-sell success._

```sql
SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  ROUND(SUM(totals.transactions) / COUNT(DISTINCT fullVisitorId), 4) AS avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE totals.transactions >= 1
  AND product.productRevenue IS NOT NULL
GROUP BY month
```

**📊 Actual Output:**
![Query 5 Output](Images/Query_5_Output.png)

**💡 Observations:**

In **July 2017 (201707)**, purchasing users averaged **4.1639 transactions per person** - a notably high repeat purchase rate indicating strong customer loyalty and basket size. This suggests that customers who make one purchase are likely to make 4+ additional purchases within the same month. This behavior points to either **subscription-based repeat purchases**, **bulk order fulfillment**, or **highly effective cross-sell merchandising**. The high repeat rate justifies investment in **loyalty programs, personalized email follow-ups, and cart recommendation engines** to maximize lifetime value from existing purchasers.

---

### Query 6: Avg Revenue per Session (July 2017 – Purchasers Only)

*Question: Calculate the average amount of money spent per session (purchasers only) in July 2017.*

> _Revenue per session reveals the monetary value each visit generates. Higher values indicate strong product pricing, effective upselling, or high-value customer segments._

```sql
SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  ROUND((SUM(product.productRevenue) / SUM(totals.visits)) / 1000000, 2) AS avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE totals.transactions >= 1
  AND product.productRevenue IS NOT NULL
GROUP BY month
```

**📊 Actual Output:**
![Query 6 Output](Images/Query_6_Output.png)

**💡 Observations:**

Purchasing users generated **$43.86 in revenue per visit in July 2017** - a strong monetization metric for an e-commerce site. This indicates that when a user enters with purchase intent, they commit meaningful spend. Benchmarking suggests this is **above-average for merchandise retail** (typically $15–$30 per session). The high revenue-per-visit supports focusing marketing spend on **intent-driven channels** (branded search, email, direct) where users are already pre-disposed to purchase, rather than broad awareness channels with lower conversion intent.

---

### Query 7: Cross-Sell Analysis – "YouTube Men's Vintage Henley" (July 2017)

*Question: Calculate other products purchased by customers who also bought "YouTube Men's Vintage Henley" in July 2017.*

> _Market basket analysis identifies which products are frequently purchased together. This drives product bundling, upsell strategies, and personalized recommendation engine training._

```sql
WITH
  buyer_list AS (
    SELECT DISTINCT fullVisitorId
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
      UNNEST(hits) AS hits,
      UNNEST(product) AS product
    WHERE product.v2ProductName = "YouTube Men's Vintage Henley"
      AND totals.transactions >= 1
      AND product.productRevenue IS NOT NULL
  )

SELECT
  product.v2ProductName AS other_purchased_products,
  SUM(product.productQuantity) AS quantity
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
JOIN buyer_list USING (fullVisitorId)
WHERE product.v2ProductName != "YouTube Men's Vintage Henley"
  AND product.productRevenue IS NOT NULL
  AND totals.transactions >= 1
GROUP BY other_purchased_products
ORDER BY quantity DESC
```

**📊 Actual Output:**
![Query 7 Output](Images/Query_7_Output.png)

**💡 Observations:**

Customers who bought the **YouTube Men's Vintage Henley** show strong affinity for **complementary accessories and apparel**. **Google Sunglasses** leads with **20 units** purchased, followed by **Google Women's Vintage Hero Tee** (7 units) and **SPF-15 Slim & Slender Lip Balm** (6 units). This cluster reveals cross-sell opportunities: **Google-branded merchandise** pairs naturally, and **sun protection accessories** (sunglasses, lip balm) align with lifestyle branding. The merchandising team should create **"Frequently Bought Together"** bundles featuring Henley + Sunglasses at a discount, and email campaigns can recommend these products to Henley purchasers, potentially increasing average order value by 15–20%.

---

### Query 8: E-Commerce Conversion Funnel (Jan–Mar 2017)

*Question: Generate a cohort map of the checkout funnel (Product View → Add to Cart → Purchase) for Jan–Mar 2017.*

> _Conversion funnel analysis identifies where users drop off during the purchase journey. High drop-off rates at specific funnel stages highlight optimization priorities (e.g., cart abandonment recovery, checkout simplification)._

```sql
WITH
  data_overview AS (
    SELECT
      FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
      eCommerceAction.action_type AS action_type,
      totals.transactions,
      product.productRevenue
    FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`,
      UNNEST(hits)    AS hits,
      UNNEST(product) AS product
    WHERE _table_suffix BETWEEN '0101' AND '0331'
  ),

  data_count AS (
    SELECT
      month,
      COUNTIF(action_type = '2') AS num_product_view,
      COUNTIF(action_type = '3') AS num_addtocart,
      COUNTIF(action_type = '6' AND productRevenue IS NOT NULL) AS num_purchase
    FROM data_overview
    GROUP BY month
    ORDER BY month
  )

SELECT
  *,
  ROUND(num_addtocart / num_product_view * 100.0, 2) AS add_to_cart_rate,
  ROUND(num_purchase  / num_product_view * 100.0, 2) AS purchase_rate
FROM data_count
```

**📊 Actual Output:**
![Query 8 Output](Images/Query_8_Output.png)

**💡 Observations:**

The **Q1 2017 conversion funnel** reveals critical optimization opportunities across all three months. **January (201701)** shows 25,787 product views, with only **7,342 add-to-cart actions (28.47% conversion)** and just **2,143 purchases (8.31% final conversion)**. **March (201703)** improves to **37.29% add-to-cart rate** and **12.64% purchase rate** - a 50% improvement in purchase conversion suggests successful checkout/product page optimizations mid-quarter. The **71.53% drop-off from product view to cart** (Jan) indicates either poor product descriptions, pricing concerns, or insufficient trust signals. Immediately actionable fixes: **(1) Add customer reviews & ratings on product pages**, **(2) Implement one-click "Add to Cart"**, **(3) Show stock scarcity alerts** to increase urgency, **(4) Test exit-intent popups with discounts** on the product page to recover the massive view-to-cart leakage.

---

## 🗂️ Project Structure

```text
Google-Analytics-Session-Analysis-Using-SQL/
├── Images/                             # Screenshots of each query's result
│   ├── banner.jpg
│   ├── Query_1_Output.png
│   ├── Query_2_Output.png
│   ├── Query_3_Output.png
│   ├── Query_4_Output.png
│   ├── Query_5_Output.png
│   ├── Query_6_Output.png
│   ├── Query_7_Output.png
│   └── Query_8_Output.png
├── SQL_Queries/                        # SQL source files for each question
│   ├── Google-Analytics-Session-Analysis.sql
└── README.md
```

---

## 🚀 Setup Instructions

To run these queries in **Google BigQuery**:

1. ☁️ **Set up a Google Cloud Platform (GCP) account:** Create one if you don't have it yet, and enable the BigQuery API.
2. 📥 **Access the public dataset:** The `bigquery-public-data.google_analytics_sample.ga_sessions_2017*` dataset is **publicly available** to all GCP users - no setup or data loading required.
3. 📂 **Open BigQuery Console:**
   - Go to [Google Cloud Console - BigQuery](https://console.cloud.google.com/bigquery)
   - Create a new Google Cloud Project if needed
4. ▶️ **Run the queries:** 
   - Open the query editor
   - Copy-paste each `.sql` file from the `SQL_Queries/` folder
   - Click **"Run"** to execute
   - Results will appear in seconds

**📌 Important Notes:**
- The dataset uses **table wildcards** (`*`) to query multiple daily shards at once. For example, `ga_sessions_2017*` matches all tables from 2017.
- Use the `_table_suffix BETWEEN '0101' AND '0331'` syntax to filter by date ranges without loading the entire year.
- The `UNNEST()` function is required to flatten nested arrays (hits, product) into a queryable format.

---
