/* Query 01: Calculate total visits, pageviews, transactions for Jan, Feb and March 2017 */

SELECT 
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  COUNT(totals.visits) AS visits,
  SUM(totals.pageviews) AS pageviews,
  SUM(totals.transactions) AS transactions
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_2017*`
WHERE _table_suffix BETWEEN '0101' AND '0331'
GROUP BY month
ORDER BY month

/* Query 02: Calculate the bounce rate per traffic source in July 2017 */

SELECT
  trafficSource.source AS source,
  SUM(totals.visits) AS total_visits,
  SUM(totals.bounces) AS total_no_of_bounces,
  ROUND(SUM(totals.bounces) / SUM(totals.visits) * 100, 3) AS bounce_rate
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`
GROUP BY source
ORDER BY total_visits DESC

/* Query 03: Calculate revenue by traffic source by week and by month in June 2017 */

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

SELECT 
  * FROM month_data
UNION ALL
SELECT 
  * FROM week_data
ORDER BY time_type, revenue DESC;

/* Query 04: Calculate average number of pageviews by purchaser type (purchasers vs non-purchasers) in June and July 2017*/

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

  purchase AS ( --transactions >= 1 AND productRevenue IS NOT NULL
    SELECT
      month,
      ROUND(SUM(pageviews) / COUNT(DISTINCT fullVisitorId), 8) AS avg_pageviews_purchase
    FROM base
    WHERE transactions >= 1 
      AND productRevenue IS NOT NULL
    GROUP BY month
  ),

  non_purchase AS ( --transactions IS NULL AND productRevenue IS NULL
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
FULL JOIN non_purchase USING (month) -- FULL JOIN (not INNER JOIN) to prevent data loss in months where one segment has zero users.
ORDER BY month

/* Query 05: Calculate the average number of transactions per user that made a purchase in July 2017 */

SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  ROUND(SUM(totals.transactions) / COUNT(DISTINCT fullVisitorId), 4) AS avg_total_transactions_per_user
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE totals.transactions >= 1
  AND product.productRevenue IS NOT NULL
GROUP BY month

/* Query 06: Calculate the average amount of money spent per session (purchasers only) in July 2017. */

SELECT
  FORMAT_DATE('%Y%m', PARSE_DATE('%Y%m%d', date)) AS month,
  ROUND((SUM(product.productRevenue) / SUM(totals.visits)) / 1000000, 2) AS avg_revenue_by_user_per_visit
FROM `bigquery-public-data.google_analytics_sample.ga_sessions_201707*`,
  UNNEST(hits) AS hits,
  UNNEST(product) AS product
WHERE totals.transactions >= 1
  AND product.productRevenue IS NOT NULL
GROUP BY month

/* Query 07: Calculate other products purchased by customers who also bought "YouTube Men's Vintage Henley" in July 2017.*/

WITH
  buyer_list AS (
    SELECT DISTINCT fullVisitorId --use DISTINCT to avoid duplication bug
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

/* Query 08: Generate a cohort map of the checkout funnel (Product View → Add to Cart → Purchase) for Jan–Mar 2017.*/

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
      COUNTIF(action_type = '2') AS num_product_view, -- Product Detail View
      COUNTIF(action_type = '3') AS num_addtocart, -- Add to Cart
      COUNTIF(action_type = '6' AND productRevenue IS NOT NULL) AS num_purchase -- Purchase
    FROM data_overview
    GROUP BY month
    ORDER BY month
  )

SELECT
  *,
  ROUND(num_addtocart / num_product_view * 100.0, 2) AS add_to_cart_rate,
  ROUND(num_purchase  / num_product_view * 100.0, 2) AS purchase_rate
FROM data_count

