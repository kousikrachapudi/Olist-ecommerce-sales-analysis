-- =====================================================================
-- OLIST E-COMMERCE ANALYSIS | STEP 1: CREATE DATABASE, TABLES, LOAD CSVs
-- Run in MySQL Workbench (MySQL 8.0+). Change @PATH lines below first.
-- =====================================================================

CREATE DATABASE IF NOT EXISTS olist;
USE olist;

-- ---------- TABLES ----------
DROP TABLE IF EXISTS order_reviews, order_payments, order_items, orders, customers, products, category_translation;

CREATE TABLE customers (
  customer_id              CHAR(32) PRIMARY KEY,
  customer_unique_id       CHAR(32) NOT NULL,
  customer_zip_code_prefix VARCHAR(10),
  customer_city            VARCHAR(100),
  customer_state           CHAR(2),
  INDEX idx_unique (customer_unique_id)
);

CREATE TABLE orders (
  order_id                      CHAR(32) PRIMARY KEY,
  customer_id                   CHAR(32) NOT NULL,
  order_status                  VARCHAR(20),
  order_purchase_timestamp      DATETIME,
  order_approved_at             DATETIME,
  order_delivered_carrier_date  DATETIME,
  order_delivered_customer_date DATETIME,
  order_estimated_delivery_date DATETIME,
  INDEX idx_cust (customer_id),
  INDEX idx_status (order_status)
);

CREATE TABLE order_items (
  order_id      CHAR(32) NOT NULL,
  order_item_id INT NOT NULL,
  product_id    CHAR(32),
  seller_id     CHAR(32),
  price         DECIMAL(10,2),
  freight_value DECIMAL(10,2),
  PRIMARY KEY (order_id, order_item_id),
  INDEX idx_prod (product_id)
);

CREATE TABLE order_payments (
  order_id             CHAR(32) NOT NULL,
  payment_sequential   INT,
  payment_type         VARCHAR(20),
  payment_installments INT,
  payment_value        DECIMAL(10,2),
  INDEX idx_pay_order (order_id)
);

CREATE TABLE order_reviews (
  review_id               CHAR(32),
  order_id                CHAR(32),
  review_score            TINYINT,
  review_creation_date    DATETIME,
  review_answer_timestamp DATETIME,
  INDEX idx_rev_order (order_id)
);

CREATE TABLE products (
  product_id            CHAR(32) PRIMARY KEY,
  product_category_name VARCHAR(100),
  product_weight_g      INT
);

CREATE TABLE category_translation (
  product_category_name         VARCHAR(100) PRIMARY KEY,
  product_category_name_english VARCHAR(100)
);

-- ---------- WHERE TO PUT THE CSV FILES ----------
-- Run this first and note the folder it shows:
--     SHOW VARIABLES LIKE 'secure_file_priv';
-- MySQL can only read files from that folder. Copy all the Olist CSV files into it.
-- Then, if your folder is different from the one used below, use Find and Replace
-- to change  C:/ProgramData/MySQL/MySQL Server 8.0/Uploads  to your folder
-- (forward slashes, no slash at the end).

-- ---------- LOAD DATA ----------

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_customers_dataset.csv'
INTO TABLE customers CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, @state)
SET customer_state = TRIM(TRAILING '\r' FROM @state);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_orders_dataset.csv'
INTO TABLE orders CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, customer_id, order_status, @purchase, @approved, @carrier, @delivered, @estimated)
SET order_purchase_timestamp      = NULLIF(@purchase, ''),
    order_approved_at             = NULLIF(@approved, ''),
    order_delivered_carrier_date  = NULLIF(@carrier, ''),
    order_delivered_customer_date = NULLIF(@delivered, ''),
    order_estimated_delivery_date = NULLIF(TRIM(TRAILING '\r' FROM @estimated), '');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_items_dataset.csv'
INTO TABLE order_items CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, order_item_id, product_id, seller_id, @shipping_limit, price, @freight)
SET freight_value = TRIM(TRAILING '\r' FROM @freight);

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_payments_dataset.csv'
INTO TABLE order_payments CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, payment_sequential, payment_type, payment_installments, @val)
SET payment_value = TRIM(TRAILING '\r' FROM @val);

-- Reviews: comment text columns are skipped (not needed, and they contain line breaks)
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_order_reviews_dataset.csv'
INTO TABLE order_reviews CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(review_id, order_id, review_score, @title, @message, @created, @answered)
SET review_creation_date    = NULLIF(@created, ''),
    review_answer_timestamp = NULLIF(TRIM(TRAILING '\r' FROM @answered), '');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/olist_products_dataset.csv'
INTO TABLE products CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_id, @cat, @n1, @n2, @n3, @weight, @n4, @n5, @n6)
SET product_category_name = NULLIF(@cat, ''),
    product_weight_g      = NULLIF(@weight, '');

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/product_category_name_translation.csv'
INTO TABLE category_translation CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
LINES TERMINATED BY '\n' IGNORE 1 LINES
(@cat, @eng)
SET product_category_name         = REPLACE(@cat, CONVERT(0xEFBBBF USING utf8mb4), ''),
    product_category_name_english = TRIM(TRAILING '\r' FROM @eng);

-- ---------- CHECK ROW COUNTS ----------
-- Expected: customers 99441 | orders 99441 | order_items 112650 | order_payments 103886
--           order_reviews ~99-100K (varies by Kaggle version) | products 32951 | category_translation 71
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;