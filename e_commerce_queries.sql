CREATE DATABASE e_commerce;

CREATE TABLE customers
(
	Customer_ID	TEXT,
	Customer_Name TEXT,
	Gender TEXT,
	Age	INT,
	Age_Group TEXT, 	
	Date_of_Birth TEXT,
	Email	TEXT,
	Phone TEXT,
	City	TEXT,
	State	TEXT,
	Pincode	INT,
	Registration_Date	TEXT,
	Customer_Tier	TEXT,
	Total_Orders	INT,
	Total_Spent DECIMAL(10,2)
);

SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/jhern/OneDrive/Documents/JJ/SQL + POWERBI/REAL/E-Commerce/customers.csv'
INTO TABLE customers
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES; -- Use this line to skip the CSV header row

CREATE TABLE products
(
	Product_ID	TEXT,
    Product_Name	TEXT,
    Category	TEXT,
    Brand	TEXT,
    Original_Price DECIMAL(10,2),	
    Discount_Percent INT,
    Discount_Amount	DECIMAL(10,2),
    Selling_Price	DECIMAL(10,2),
    Stock_Quantity	INT,
    Weight_kg	FLOAT,
    Avg_Rating	FLOAT,
    Total_Reviews INT
);

LOAD DATA LOCAL INFILE 'C:/Users/jhern/OneDrive/Documents/JJ/SQL + POWERBI/REAL/E-Commerce/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES; -- Use this line to skip the CSV header row

CREATE TABLE sales
(
	Order_ID TEXT,	
    Customer_ID	TEXT,
    Product_ID	TEXT,
    Order_Date	TEXT,
    Order_Time	TIME,
    Delivery_Date	TEXT,
    Quantity	INT,
    Unit_Price	DECIMAL(10,2),
    Order_Value	DECIMAL(10,2),
    Shipping_Cost	FLOAT,
    Coupon_Code	TEXT,
    Coupon_Discount	FLOAT,
    Total_Amount	DECIMAL(10,2),
    Payment_Mode	TEXT,
    Order_Status	TEXT,
    Rating	TEXT,
    Review_Text	TEXT,	
    City TEXT,	
    State	TEXT,
    Customer_Age INT,	
    Customer_Age_Group TEXT
);

LOAD DATA LOCAL INFILE 'C:/Users/jhern/OneDrive/Documents/JJ/SQL + POWERBI/REAL/E-Commerce/sales.csv'
INTO TABLE sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES; -- Use this line to skip the CSV header row


-- DATA CLEANING AND PREPARATION
ALTER TABLE customers
MODIFY COLUMN Date_of_Birth DATE,
MODIFY COLUMN Registration_Date DATE;

UPDATE sales
SET Order_Date = STR_TO_DATE(Order_Date, "%m/%d/%Y");

UPDATE sales
SET Delivery_Date = STR_TO_DATE(Delivery_Date, "%m/%d/%Y");

ALTER TABLE sales
MODIFY COLUMN Order_Date DATE,
MODIFY COLUMN Delivery_Date DATE;

UPDATE sales
SET Rating = NULL 
WHERE Rating = '';

ALTER TABLE sales
MODIFY COLUMN Rating INT NULL;

-- UPDATING BLANK VALUES IN COLUMNS WITH FRIENDLY MESSAGE
UPDATE sales 
SET Coupon_Code = 'No coupon used' 
WHERE Coupon_Code IS NULL OR Coupon_Code = '';

UPDATE sales 
SET Review_Text = 'No written review left' 
WHERE Review_Text IS NULL OR Review_Text = '';


-- PART 1: OVERVIEW & MACRO KPIs

-- 1. High-Level Counts: Total Unique Orders, Active Customers (with Purchases), and Products Sold in Sales
SELECT 
	COUNT(DISTINCT Order_ID) AS total_unique_orders,
    COUNT(DISTINCT Customer_ID) AS total_unique_customers,
    COUNT(DISTINCT Product_ID) AS total_unique_products
FROM sales;


-- 2. Order Status Breakdown: Total Sales Value across all Order Lifecycle Stages
SELECT 
	SUM(CASE WHEN Order_Status = 'Delivered' THEN Total_Amount ELSE 0 END) AS total_sales,
    SUM(CASE WHEN Order_Status = 'Returned' THEN Total_Amount ELSE 0 END) AS refunded_sales,
    SUM(CASE WHEN Order_Status = 'Cancelled' THEN Total_Amount ELSE 0 END) AS lost_sales,
    SUM(CASE WHEN Order_Status = 'Processing' THEN Total_Amount ELSE 0 END) AS processing_sales,
    SUM(CASE WHEN Order_Status = 'Shipped' THEN Total_Amount ELSE 0 END) AS pending_sales,
    SUM(Total_Amount) AS gross_potential_sales
FROM sales;

-- PART 2: REALIZED REVENUE (Delivered Orders Only)

-- 1. Core Performance KPIs: Total Sales, Delivered Orders, and Average Order Value (AOV)
SELECT 
	SUM(Total_Amount) AS total_sales,
    COUNT(DISTINCT Order_ID) AS total_orders,
    SUM(Total_Amount) / COUNT(DISTINCT Order_ID) AS avg_order_value
FROM sales
WHERE Order_Status = 'Delivered';

-- 2. Sales Performance by Product Category (with percentage contribution)
SELECT
	p.Category,
    SUM(s.Total_Amount) AS total_sales,
	ROUND((SUM(s.Total_Amount) / (SELECT SUM(Total_Amount) FROM sales WHERE Order_Status = 'Delivered')) * 100, 2) AS sales_percentage
FROM sales AS s
INNER JOIN products AS p
	ON s.Product_ID = p.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Category
ORDER BY total_sales DESC;

-- 3. Top 10 Best-Performing Brands by Sales Revenue
SELECT
	p.Brand,
    SUM(s.Total_Amount) AS total_sales
FROM sales AS s
INNER JOIN products AS p
	ON s.Product_ID = p.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Brand
ORDER BY total_sales DESC
LIMIT 10;

-- 4. Monthly Revenue Trend and Month-over-Month (MoM) Growth Analysis
SELECT
	DATE_FORMAT(Order_Date, "%Y-%m") AS `year_month`,
    COUNT(Order_ID) AS total_orders,
    SUM(Total_Amount) AS monthly_sales,
    LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")) AS previous_month_sales,
    SUM(Total_Amount) - LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")) AS MoM_growth,
    ROUND((SUM(Total_Amount) - LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m"))) * 100 
    / LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")),2) AS MoM_growth_pct
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY `year_month`
ORDER BY `year_month`;

-- 5. Geographic Performance: Top States by Sales Revenue and Unit Volume
SELECT
	State,
    COUNT(DISTINCT Order_ID) AS total_orders,
    SUM(Quantity) AS total_sold_units,
	SUM(Total_Amount) AS total_sales
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY State
ORDER BY total_sales DESC;

-- 6. Customer Segmentation: Revenue Contribution Share by Customer Tier
SELECT
	c.Customer_Tier,
    SUM(s.Total_Amount) AS total_sales,
    ROUND((SUM(s.Total_Amount)*100) / (SELECT SUM(Total_Amount) FROM sales WHERE Order_Status = 'Delivered'),2) AS sales_pct
FROM sales AS s
INNER JOIN customers AS c
	ON s.Customer_ID = c.Customer_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY c.Customer_Tier
ORDER BY total_sales DESC;

-- 7. Customer Demographics: Sales Performance by Age Group
SELECT 
	Customer_Age_Group,
    COUNT(DISTINCT Order_ID) AS total_orders,
    SUM(Quantity) AS total_quantity_sold,
    SUM(Total_Amount) AS total_sales
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY Customer_Age_Group
ORDER BY total_sales DESC;

-- 8. Payment Preferences: Transaction Volume and Revenue Share by Payment Mode
SELECT
	Payment_Mode,
    COUNT(DISTINCT Order_ID) AS total_orders,
    SUM(Quantity) AS total_quantity_sold,
    SUM(Total_Amount) AS total_sales,
    ROUND((SUM(Total_Amount) * 100) / (SELECT SUM(Total_Amount) FROM sales WHERE Order_Status = 'Delivered'),2) AS sales_pct
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY Payment_Mode
ORDER BY total_sales DESC;

-- 9. Top 10 Customers by Realized Revenue
SELECT
    c.Customer_ID,
    c.Customer_Name,
    c.Customer_Tier,
    COUNT(DISTINCT s.Order_ID) AS total_orders,
    SUM(s.Total_Amount) AS total_sales
FROM sales AS s
INNER JOIN customers AS c
    ON s.Customer_ID = c.Customer_ID
WHERE s.Order_Status = 'Delivered'  
GROUP BY c.Customer_ID, c.Customer_Name, c.Customer_Tier
ORDER BY total_sales DESC
LIMIT 10;                               

-- PART 3: PRODUCT & INVENTORY INSIGHTS

-- 1. Top 10 Best-Selling Products (Ranked by Units Sold)
WITH cte AS
(
SELECT
	p.Product_ID,
    p.Product_Name,
    p.Stock_Quantity,
    SUM(s.Quantity) AS total_units_sold
FROM products AS p
INNER JOIN sales AS s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Product_ID, p.Product_Name, p.Stock_Quantity
),
ranked_cte AS
(
SELECT 
	*,
    ROW_NUMBER() OVER(ORDER BY total_units_sold DESC) AS unit_rank
FROM cte
)
SELECT *
FROM ranked_cte
WHERE unit_rank <= 10
ORDER BY unit_rank ASC;

-- 2. Revenue & Total Units Sold by Discount Bracket
SELECT
	CASE 
		WHEN p.Discount_Percent BETWEEN 0 AND 10 THEN '0-10%'
        WHEN p.Discount_Percent BETWEEN 11 AND 25 THEN '11-25%'
        WHEN p.Discount_Percent BETWEEN 26 AND 50 THEN '26-50%'
	END AS discount_brackets,
	SUM(s.Total_Amount) AS total_sales,
	SUM(s.Quantity) AS total_units_sold
FROM products AS p
INNER JOIN sales AS s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY discount_brackets
ORDER BY total_sales DESC;


-- PART 4: OPERATIONS & LOGISTICS PERFORMANCE

-- 1. Supply Chain Audit: Total Delivered Orders by State
SELECT
    State,
    COUNT(DISTINCT Order_ID) AS total_orders_delivered
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY State
ORDER BY total_orders_delivered DESC;

-- 2. Total Orders by Delivery Speed Tiers
WITH delivery_days AS (
    SELECT
        Order_ID,
        DATEDIFF(Delivery_Date, Order_Date) AS days_delivered,
        Total_Amount
    FROM sales
    WHERE Order_Status = 'Delivered'
)
SELECT
    CASE 
        WHEN days_delivered <= 3 THEN 'Fast (1-3 Days)'
        WHEN days_delivered BETWEEN 4 AND 5 THEN 'Standard (4-5 Days)'
        ELSE 'Slow (6+ Days)'
    END AS delivery_speed_tier,
    COUNT(DISTINCT Order_ID) AS total_orders
FROM delivery_days
GROUP BY delivery_speed_tier;
