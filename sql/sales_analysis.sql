-- =====================================================
-- Retail Superstore Sales Analysis (MySQL 8+)
-- Dataset: superstore_cleaned.csv (9,986 rows, 2019-2022)
-- =====================================================

-- -----------------------------------------------------
-- 0. SETUP
-- -----------------------------------------------------
CREATE DATABASE IF NOT EXISTS Full_project;
USE Full_project;

DROP TABLE IF EXISTS superstore;

CREATE TABLE superstore (
    order_id      VARCHAR(50),
    order_date    DATE,            -- CSV dates must be in YYYY-MM-DD format
    ship_date     DATE,
    customer      VARCHAR(255),
    manufactory   VARCHAR(255),
    product_name  VARCHAR(255),
    segment       VARCHAR(50),
    category      VARCHAR(50),
    subcategory   VARCHAR(50),
    region        VARCHAR(50),
    zip           VARCHAR(20),
    city          VARCHAR(100),
    state         VARCHAR(100),
    country       VARCHAR(100),
    discount      DECIMAL(5, 2),
    profit        DECIMAL(10, 4),
    quantity      INT,
    sales         DECIMAL(10, 4),
    profit_margin DECIMAL(10, 4)
);

-- Enable local file loading BEFORE running LOAD DATA
SET GLOBAL local_infile = 1;

-- Change the path to where the CSV is saved on your machine
LOAD DATA LOCAL INFILE 'path/to/superstore_cleaned.csv'
INTO TABLE superstore
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- Quick check
SELECT COUNT(*) AS total_rows FROM superstore;   -- expected: 9986


-- -----------------------------------------------------
-- 1. EXECUTIVE FINANCIAL OVERVIEW
-- -----------------------------------------------------

-- Q1: Total revenue
SELECT ROUND(SUM(sales), 2) AS revenue
FROM superstore;

-- Q2: Net profit and overall profit margin %
SELECT ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM superstore;

-- Q3: Yearly sales, profit and year-over-year sales growth
WITH yearly AS (
    SELECT YEAR(order_date) AS yr,
           SUM(sales)  AS sales,
           SUM(profit) AS profit
    FROM superstore
    GROUP BY YEAR(order_date)
)
SELECT yr,
       ROUND(sales, 2)  AS total_sales,
       ROUND(profit, 2) AS total_profit,
       ROUND((sales - LAG(sales) OVER (ORDER BY yr))
             / LAG(sales) OVER (ORDER BY yr) * 100, 2) AS sales_growth_pct
FROM yearly
ORDER BY yr;


-- -----------------------------------------------------
-- 2. REGIONAL & GEOGRAPHIC PERFORMANCE
-- -----------------------------------------------------

-- Q4: Which regions drive the highest revenue?
SELECT region,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(sales), 2)     AS total_sales
FROM superstore
GROUP BY region
ORDER BY total_sales DESC;

-- Q5: Profit margin by region (which regions underperform despite high sales?)
SELECT region,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM superstore
GROUP BY region
ORDER BY profit_margin_pct DESC;

-- Q6: Top 10 states by profit
SELECT state,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM superstore
GROUP BY state
ORDER BY total_profit DESC
LIMIT 10;

-- Q7: Loss-making states
SELECT state,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM superstore
GROUP BY state
HAVING SUM(profit) < 0
ORDER BY total_profit ASC;


-- -----------------------------------------------------
-- 3. PRODUCT & CATEGORY PROFITABILITY
-- -----------------------------------------------------

-- Q8: Revenue and profit by category
SELECT category,
       ROUND(SUM(sales), 2)  AS revenue,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM superstore
GROUP BY category
ORDER BY revenue DESC;

-- Q9: Top 5 most profitable sub-categories
SELECT category, subcategory,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(SUM(profit) / SUM(sales) * 100, 2) AS profit_margin_pct
FROM superstore
GROUP BY category, subcategory
ORDER BY total_profit DESC
LIMIT 5;

-- Q10: Sub-categories operating at a net loss
SELECT category, subcategory,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM superstore
GROUP BY category, subcategory
HAVING SUM(profit) < 0
ORDER BY total_profit ASC;

-- Q11: Rank sub-categories by profit within each category (window function)
SELECT category, subcategory,
       ROUND(SUM(profit), 2) AS total_profit,
       RANK() OVER (PARTITION BY category ORDER BY SUM(profit) DESC) AS rank_in_category
FROM superstore
GROUP BY category, subcategory
ORDER BY category, rank_in_category;

-- Q12: Top 5 products by sales
SELECT product_name,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM superstore
GROUP BY product_name
ORDER BY total_sales DESC
LIMIT 5;


-- -----------------------------------------------------
-- 4. CUSTOMER SEGMENT BREAKDOWN
-- -----------------------------------------------------

-- Q13: Sales and profit by segment
SELECT segment,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit
FROM superstore
GROUP BY segment
ORDER BY total_sales DESC;

-- Q14: Which segment has the highest average order value?
SELECT segment,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(sales), 2)     AS total_sales,
       ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM superstore
GROUP BY segment
ORDER BY avg_order_value DESC;


-- -----------------------------------------------------
-- 5. DISCOUNT STRATEGY & MARGIN IMPACT
-- -----------------------------------------------------

-- Q15: Profit at each discount level
SELECT discount,
       COUNT(*)              AS line_items,
       ROUND(SUM(sales), 2)  AS total_sales,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(AVG(profit), 2) AS avg_profit_per_item
FROM superstore
GROUP BY discount
ORDER BY discount ASC;

-- Q16: At what discount level does profit turn negative? (grouped into bands)
SELECT CASE
           WHEN discount = 0    THEN '0% (no discount)'
           WHEN discount <= 0.2 THEN '1-20%'
           WHEN discount <= 0.4 THEN '21-40%'
           ELSE '40%+'
       END AS discount_band,
       COUNT(*)              AS line_items,
       ROUND(SUM(profit), 2) AS total_profit,
       ROUND(AVG(profit), 2) AS avg_profit_per_item
FROM superstore
GROUP BY discount_band
ORDER BY MIN(discount);
