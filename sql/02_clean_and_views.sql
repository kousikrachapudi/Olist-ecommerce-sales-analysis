-- =====================================================================
-- STEP 2: DATA QUALITY CHECKS + CLEAN BASE VIEW
-- =====================================================================
USE olist;

-- 2.1 Order status mix (we only count 'delivered' orders in revenue)
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 2.2 Delivered orders that are missing a delivery date (we will exclude them)
SELECT COUNT(*) AS delivered_missing_date
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;

-- 2.3 Duplicate order IDs (expect 0)
SELECT COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_orders FROM orders;

-- 2.4 Order items with no matching order (expect 0)
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_id IS NULL;

-- 2.5 Orders with more than one review (we average the score per order)
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) x;

-- 2.6 Products whose category has no English translation (we fall back to the Portuguese name)
SELECT COUNT(*) AS products_without_translation
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE p.product_category_name IS NOT NULL AND t.product_category_name IS NULL;

-- 2.7 CLEAN BASE VIEW: one row per delivered order, used by every analysis after this
--     customer_unique_id identifies the real person (customer_id changes with every order)
CREATE OR REPLACE VIEW v_order_summary AS
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       c.customer_city,
       o.order_purchase_timestamp,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       oi.revenue,
       oi.freight,
       oi.items,
       DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp) AS delivery_days,
       CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS is_late,
       rv.review_score
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN (SELECT order_id, SUM(price) AS revenue, SUM(freight_value) AS freight, COUNT(*) AS items
      FROM order_items GROUP BY order_id) oi ON oi.order_id = o.order_id
LEFT JOIN (SELECT order_id, AVG(review_score) AS review_score
           FROM order_reviews GROUP BY order_id) rv ON rv.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL;

-- 2.8 Quick sanity check on the clean view
SELECT COUNT(*) AS delivered_orders,
       COUNT(DISTINCT customer_unique_id) AS unique_customers,
       COUNT(DISTINCT customer_state) AS states,
       ROUND(SUM(revenue), 2) AS total_revenue_brl,
       ROUND(AVG(revenue), 2) AS avg_order_value_brl
FROM v_order_summary;
