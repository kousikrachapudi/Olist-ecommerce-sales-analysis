-- =====================================================================
-- STEP 4: RFM CUSTOMER SEGMENTATION
-- Recency (how recently they bought), Frequency (orders), Monetary (spend)
-- NTILE(5) splits customers into 5 equal groups. 5 = best.
-- =====================================================================
USE olist;

CREATE OR REPLACE VIEW v_rfm AS
WITH base AS (
  SELECT customer_unique_id,
         COUNT(*) AS frequency,
         SUM(revenue) AS monetary,
         MAX(order_purchase_timestamp) AS last_order
  FROM v_order_summary
  GROUP BY customer_unique_id
),
snap AS (
  SELECT DATE_ADD(MAX(order_purchase_timestamp), INTERVAL 1 DAY) AS snapshot_date FROM v_order_summary
),
scored AS (
  SELECT b.*,
         DATEDIFF(s.snapshot_date, b.last_order) AS recency_days,
         NTILE(5) OVER (ORDER BY b.last_order) AS r_score,   -- most recent buyers get 5
         NTILE(5) OVER (ORDER BY b.monetary)   AS m_score    -- biggest spenders get 5
  FROM base b CROSS JOIN snap s
)
SELECT scored.*,
       CASE
         WHEN frequency >= 2                THEN 'Repeat customers'
         WHEN r_score >= 4 AND m_score >= 4 THEN 'Champions'
         WHEN r_score <= 2 AND m_score >= 4 THEN 'At risk (high spend)'
         WHEN r_score >= 4                  THEN 'New, lower spend'
         ELSE 'Hibernating'
       END AS segment
FROM scored;

-- Segment summary: how many customers and how much revenue in each group
SELECT segment,
       COUNT(*) AS customers,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS customer_pct,
       ROUND(SUM(monetary), 0) AS revenue,
       ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS revenue_pct,
       ROUND(AVG(monetary), 2) AS avg_spend
FROM v_rfm
GROUP BY segment
ORDER BY revenue DESC;
