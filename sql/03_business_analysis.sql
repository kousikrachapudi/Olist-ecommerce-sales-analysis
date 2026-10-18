-- =====================================================================
-- STEP 3: BUSINESS QUESTIONS (SQL ANALYSIS)
-- Currency is Brazilian reais (BRL). Revenue = item price, freight excluded.
-- =====================================================================
USE olist;

-- Q1. Monthly revenue, orders, and month-over-month growth (LAG window function)
--     Jan 2017 to Aug 2018 only: 2016 is tiny and Sep/Oct 2018 are incomplete.
WITH monthly AS (
  SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m') AS ym,
         COUNT(*) AS orders,
         ROUND(SUM(revenue), 2) AS revenue
  FROM v_order_summary
  WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-09-01'
  GROUP BY ym
)
SELECT ym, orders, revenue,
       ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY ym)) / LAG(revenue) OVER (ORDER BY ym), 1) AS mom_growth_pct
FROM monthly
ORDER BY ym;

-- Q2. Top 10 product categories by revenue, with share of total
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(100 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 1) AS revenue_share_pct
FROM order_items oi
JOIN v_order_summary v ON v.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- Q3. Top 3 categories per year (RANK + PARTITION BY)
WITH cat_year AS (
  SELECT YEAR(v.order_purchase_timestamp) AS yr,
         COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
         SUM(oi.price) AS revenue
  FROM order_items oi
  JOIN v_order_summary v ON v.order_id = oi.order_id
  JOIN products p ON p.product_id = oi.product_id
  LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
  GROUP BY yr, category
)
SELECT yr, category, ROUND(revenue, 2) AS revenue, rnk
FROM (SELECT cy.*, RANK() OVER (PARTITION BY yr ORDER BY revenue DESC) AS rnk FROM cat_year cy) ranked
WHERE rnk <= 3 AND yr IN (2017, 2018)
ORDER BY yr, rnk;

-- Q4. Top 10 states by revenue, with average order value
SELECT customer_state,
       COUNT(*) AS orders,
       ROUND(SUM(revenue), 2) AS revenue,
       ROUND(AVG(revenue), 2) AS avg_order_value,
       ROUND(100 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS revenue_share_pct
FROM v_order_summary
GROUP BY customer_state
ORDER BY revenue DESC
LIMIT 10;

-- Q5. Delivery performance overall
SELECT ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
       ROUND(100 * AVG(is_late), 1) AS late_orders_pct
FROM v_order_summary;

-- Q6. Slowest states (at least 500 orders so the average is meaningful)
SELECT customer_state,
       COUNT(*) AS orders,
       ROUND(AVG(delivery_days), 1) AS avg_delivery_days,
       ROUND(100 * AVG(is_late), 1) AS late_pct
FROM v_order_summary
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY avg_delivery_days DESC
LIMIT 10;

-- Q7. Do late deliveries get worse reviews?
SELECT CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 2) AS avg_review_score
FROM v_order_summary
WHERE review_score IS NOT NULL
GROUP BY is_late;

-- Q8. Repeat customers (using customer_unique_id, not customer_id)
SELECT COUNT(*) AS customers,
       SUM(order_count > 1) AS repeat_customers,
       ROUND(100 * AVG(order_count > 1), 1) AS repeat_pct
FROM (SELECT customer_unique_id, COUNT(*) AS order_count
      FROM v_order_summary GROUP BY customer_unique_id) x;

-- Q9. Payment methods: share of payments and value
SELECT payment_type,
       COUNT(*) AS payments,
       ROUND(SUM(payment_value), 0) AS total_value,
       ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 1) AS value_share_pct
FROM order_payments
WHERE order_id IN (SELECT order_id FROM v_order_summary)
GROUP BY payment_type
ORDER BY total_value DESC;
