-- =====================================================================
-- STEP 5: VIEWS FOR POWER BI (one view per dashboard page)
-- In Power BI: Get Data > MySQL database > server: localhost, database: olist
-- (needs MySQL Connector/NET). If the connector gives trouble, run each
-- SELECT * FROM view, then in the Workbench result grid click Export to save a CSV.
-- =====================================================================
USE olist;

CREATE OR REPLACE VIEW v_kpi_monthly AS
SELECT DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS month_start,
       YEAR(order_purchase_timestamp) AS yr,
       customer_state,
       COUNT(*) AS orders,
       SUM(revenue) AS revenue,
       SUM(freight) AS freight,
       AVG(delivery_days) AS avg_delivery_days,
       SUM(is_late) AS late_orders,
       AVG(review_score) AS avg_review_score
FROM v_order_summary
WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-09-01'
GROUP BY month_start, yr, customer_state;

CREATE OR REPLACE VIEW v_category_sales AS
SELECT YEAR(v.order_purchase_timestamp) AS yr,
       v.customer_state,
       COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       SUM(oi.price) AS revenue
FROM order_items oi
JOIN v_order_summary v ON v.order_id = oi.order_id
JOIN products p ON p.product_id = oi.product_id
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE v.order_purchase_timestamp >= '2017-01-01' AND v.order_purchase_timestamp < '2018-09-01'
GROUP BY yr, v.customer_state, category;

CREATE OR REPLACE VIEW v_payment_mix AS
SELECT p.payment_type,
       COUNT(*) AS payments,
       SUM(p.payment_value) AS total_value
FROM order_payments p
JOIN v_order_summary v ON v.order_id = p.order_id
GROUP BY p.payment_type;

-- RFM page uses the v_rfm view created in step 4

-- Check that every view returns rows
SELECT 'v_kpi_monthly' AS view_name, COUNT(*) AS row_count FROM v_kpi_monthly
UNION ALL SELECT 'v_category_sales', COUNT(*) FROM v_category_sales
UNION ALL SELECT 'v_payment_mix', COUNT(*) FROM v_payment_mix
UNION ALL SELECT 'v_rfm', COUNT(*) FROM v_rfm;
