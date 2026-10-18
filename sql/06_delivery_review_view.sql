-- =====================================================================
-- EXTRA VIEW FOR POWER BI PAGE 4: late vs on-time orders and review scores
-- =====================================================================
USE olist;

CREATE OR REPLACE VIEW v_delivery_review AS
SELECT CASE WHEN is_late = 1 THEN 'Late' ELSE 'On time' END AS delivery_status,
       customer_state,
       YEAR(order_purchase_timestamp) AS yr,
       COUNT(*) AS orders,
       SUM(review_score) AS review_sum,
       COUNT(review_score) AS review_count
FROM v_order_summary
WHERE order_purchase_timestamp >= '2017-01-01' AND order_purchase_timestamp < '2018-09-01'
GROUP BY delivery_status, customer_state, yr;

-- Check: expect Late about 2.6 and On time about 4.3
SELECT delivery_status,
       SUM(orders) AS orders,
       ROUND(SUM(review_sum) / SUM(review_count), 2) AS avg_review
FROM v_delivery_review
GROUP BY delivery_status;
