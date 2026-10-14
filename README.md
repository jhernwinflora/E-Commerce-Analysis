# 🛒 E-Commerce Sales & Customer Behavior Analytics

### Project Overview

In competitive e-commerce landscapes, understanding revenue drivers, customer lifetime value (CLV), and inventory health is critical for sustainable growth. This project analyzes a comprehensive retail dataset comprising customer demographics, product catalogs, and transactional sales data.

By leveraging advanced SQL queries and relational modeling, this project answers 12 key business questions to uncover revenue trends, geographic hotspots, product underperformance, and delivery bottlenecks.

### Data Source
Primary Dataset: 
* [customers.csv](./customers.csv)
* [products.csv](./products.csv)
* [sales.csv](./sales.csv)

### Dataset & Database Schema

The relational database (e_commerce) consists of three core tables:
customers: Customer demographics, registration dates, tiers (Gold, Silver, Platinum), total orders, and lifetime spend.
products: Product catalog details, original vs. selling prices, discount percentages, stock quantities, weights, and ratings.
sales: Transactional records including order dates, delivery dates, quantities, order values, shipping costs, coupon codes, payment modes, and order statuses (Delivered, Returned, Cancelled).

### Tools 
* Excel - Raw Data
* MySQL Workbench - Queries
* Power BI - Dax and Dashboard

### 🧹 Data Cleaning & Preparation
Before analysis, data quality checks and transformations were executed in MySQL to ensure data integrity:
Handling Missing Values: Standardized blank rating fields to NULL and replaced missing review texts and coupon codes with user-friendly placeholder strings ('No written review left', 'No coupon used').
```sql
UPDATE sales
SET Rating = NULL 
WHERE Rating = '';

ALTER TABLE sales
MODIFY COLUMN Rating INT NULL;

UPDATE sales 
SET Coupon_Code = 'No coupon used' 
WHERE Coupon_Code IS NULL OR Coupon_Code = '';

UPDATE sales 
SET Review_Text = 'No written review left' 
WHERE Review_Text IS NULL OR Review_Text = '';
```

Type Casting & Date Formatting: Converted string-based dates (MM/DD/YYYY) into proper SQL DATE data types using STR_TO_DATE() to enable time-series analysis and lead-time calculations.
```sql
UPDATE sales
SET Order_Date = STR_TO_DATE(Order_Date, "%m/%d/%Y");

UPDATE sales
SET Delivery_Date = STR_TO_DATE(Delivery_Date, "%m/%d/%Y");
```

### 🔍 Key Business Questions & SQL Insights
```sql
SELECT
	SUM(Total_Amount) AS total_sales,
    COUNT(DISTINCT Order_ID) AS total_orders,
    ROUND(SUM(Total_Amount) / COUNT(DISTINCT Order_ID),2) AS avg_order_value
FROM sales
WHERE Order_Status = 'Delivered';

-- 1. Executive & Sales Revenue Analysis
-- How are total revenue, total order volume, 
-- and Average Order Value (AOV) trending month-over-month? Are there seasonal peaks?

SELECT
	DATE_FORMAT(Order_Date, "%Y-%m") AS `Year_Month`,
    COUNT(DISTINCT Order_ID) AS Total_Delivered_Orders,
    ROUND((SUM(Total_Amount) / COUNT(Order_ID)),2) AS Average_Order_Value,
    SUM(Total_Amount) AS Total_Sales,
    LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")) AS Previous_Month_Sales,
    SUM(Total_Amount) - LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")) AS MoM_Growth,
    ROUND(((SUM(Total_Amount) - LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m")))
    / LAG(SUM(Total_Amount)) OVER(ORDER BY DATE_FORMAT(Order_Date, "%Y-%m"))) * 100, 2) AS MoM_Growth_Pct
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY `Year_Month`
ORDER BY `Year_Month`;

-- 2. Revenue Contribution by Product Category & Brand
-- Are the highest-selling brand also the highest-revenue products?
WITH ranked AS
(
SELECT
	p.Category,
    p.Brand,
    SUM(s.Quantity) AS total_units_sold,
    SUM(s.Total_Amount) AS total_sales,
    ROUND(AVG(s.Coupon_Discount),2) AS avg_discount_given
FROM products as p
INNER JOIN sales as s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Category, p.Brand
)
SELECT
	*,
    DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS unit_rank,
    DENSE_RANK() OVER(ORDER BY total_sales DESC) AS revenue_rank
FROM ranked;

-- 3. Geographic Sales Distribution
-- Which states and top 10 cities generate the highest sales volume and revenue?
SELECT 
	State,
	City,
	COUNT(DISTINCT Customer_ID) AS total_customers,
	COUNT(DISTINCT Order_ID) AS total_orders,
	SUM(Quantity) AS total_units_sold,
	SUM(Total_Amount) AS total_revenue
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY State, City
ORDER BY total_revenue DESC
LIMIT 10;

-- 4. Customer Tier & Lifetime Value (CLV)
-- How does total revenue and average spending vary across customer tiers 
-- (Gold, Silver, Platinum), and do higher tiers order more frequently?
SELECT
	c.Customer_Tier,
	SUM(s.Total_Amount) AS total_revenue,
	ROUND(COUNT(DISTINCT s.Order_ID) / COUNT(DISTINCT c.Customer_ID),2) AS avg_order_count_per_customer,
    ROUND(SUM(s.Total_Amount) / COUNT(DISTINCT c.Customer_ID),2) AS avg_spending_per_customer,
    ROUND(SUM(s.Total_Amount) / SUM(SUM(s.Total_Amount)) OVER() * 100,2) AS revenue_contribution_pct
FROM customers AS c
INNER JOIN sales AS s
	ON c.Customer_ID = s.Customer_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY c.Customer_Tier
ORDER BY total_revenue DESC;

-- 5. Business Question: Which age groups and genders spend the most, and what categories do they prefer?
WITH cte AS
(
	SELECT
		c.Gender,
		s.Customer_Age_Group,
		p.Category,
		COUNT(DISTINCT s.Order_ID) AS total_orders,
		SUM(s.Quantity) AS total_units_sold,
		SUM(s.Total_Amount) AS total_revenue
	FROM customers AS c
	INNER JOIN sales AS s
		ON c.Customer_ID = s.Customer_ID
	INNER JOIN  products AS p
		ON s.Product_ID = p.Product_ID
	WHERE s.Order_Status = 'Delivered'
	GROUP BY c.Gender, s.Customer_Age_Group, p.Category
	ORDER BY total_revenue DESC
),
ranked_preference
AS
(
	SELECT 
		*,
		DENSE_RANK() OVER(PARTITION BY Gender, Customer_Age_Group ORDER BY total_revenue DESC) AS category_rank
	FROM cte
)
SELECT 
	*
FROM ranked_preference
ORDER BY total_revenue DESC;

-- 6. Business Question: Who are the top 20 customers by total spend, 
-- what is their preferred payment method, and when was their most recent order date?
WITH customer_sales AS
(
SELECT
	c.Customer_ID,
    c.Customer_Name,
    SUM(s.Total_Amount) AS total_spend,
    COUNT(s.Order_ID) AS total_order,
    MAX(Order_Date) AS latest_order_date
FROM customers AS c
INNER JOIN sales AS s
	ON c.Customer_ID = s.Customer_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY c.Customer_ID, c.Customer_Name
),
payment_frequency AS
(
SELECT 
	s.Customer_ID,
	s.Payment_Mode,
	COUNT(s.Order_ID) AS mode_usage_count,
	RANK() OVER (PARTITION BY s.Customer_ID ORDER BY COUNT(s.Order_ID) DESC, s.Payment_Mode ASC) AS payment_rank
    FROM sales AS s
    WHERE s.Order_Status = 'Delivered'
    GROUP BY s.Customer_ID, s.Payment_Mode
)
SELECT 
	cs.Customer_ID,
    cs.Customer_Name,
    pf.Payment_Mode AS preferred_payment_mode,
    cs.total_order,
    ROUND(cs.total_spend, 2) AS total_spend,
    latest_order_date
FROM customer_sales AS cs
INNER JOIN payment_frequency AS pf
	ON cs.Customer_ID = pf.Customer_ID
WHERE payment_rank = 1
ORDER BY total_spend DESC
LIMIT 20;

-- 7. What are the top 10 best-selling products by units sold versus revenue, and which items are in stock but underperforming?
WITH ranked_cte AS
(
SELECT
	p.Product_ID,
    p.Product_Name,
    p.Stock_Quantity,
    SUM(s.Quantity) AS total_units_sold,
    SUM(Total_Amount) AS total_revenue
FROM products AS p
INNER JOIN sales AS s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Product_ID, p.Product_Name, p.Stock_Quantity
)
SELECT 
	*,
    DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS unit_rank,
    DENSE_RANK() OVER(ORDER BY total_revenue DESC) AS revenue_rank
FROM ranked_cte;



-- 8. WHICH ITEMS ARE IN STOCK BUT UNDERPERFORMING
WITH ranked_cte AS
(
SELECT
	p.Product_ID,
    p.Product_Name,
    p.Stock_Quantity,
    SUM(s.Quantity) AS total_units_sold,
    SUM(Total_Amount) AS total_revenue
FROM products AS p
INNER JOIN sales AS s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
GROUP BY p.Product_ID, p.Product_Name, p.Stock_Quantity
),
ranked_products AS
(
SELECT 
	*,
    DENSE_RANK() OVER(ORDER BY total_units_sold DESC) AS unit_rank,
    DENSE_RANK() OVER(ORDER BY total_revenue DESC) AS revenue_rank,
    CASE 
            WHEN Stock_Quantity > 800 AND total_units_sold < 150 THEN 'High Stock / Underperforming'
            WHEN Stock_Quantity < 50 AND total_units_sold > 200 THEN 'Stockout Risk / High Demand'
            ELSE 'Healthy'
	END AS inventory_status
FROM ranked_cte
)
SELECT *
FROM ranked_products
WHERE inventory_status = 'High Stock / Underperforming'
ORDER BY Stock_Quantity DESC;

-- 9. Do higher product discount percentages (Discount_Percent)
-- lead to significantly higher sales volume, or do they negatively affect customer review ratings?
WITH cte AS
(
SELECT
	p.Product_ID,
    p.Product_Name,
    p.Discount_Percent,
	CASE 
		WHEN p.Discount_Percent BETWEEN 0 AND 10 THEN "0-10%"
        WHEN p.Discount_Percent BETWEEN 11 AND 25 THEN "11-25%"
        WHEN p.Discount_Percent BETWEEN 26 AND 50 THEN "26-50%"
	END AS discount_brackets,
	s.Order_ID,
	s.Quantity,
	s.Rating 
FROM products AS p
INNER JOIN sales AS s
	ON p.Product_ID = s.Product_ID
WHERE s.Order_Status = 'Delivered'
)
SELECT 
    discount_brackets,
    COUNT(DISTINCT Product_ID) AS total_products,
    COUNT(Order_ID) AS total_orders,
    SUM(Quantity) AS total_units_sold,
    ROUND(AVG(Quantity), 3) AS avg_quantity_per_order,
    ROUND(AVG(Rating), 2) AS avg_customer_rating
FROM cte
GROUP BY discount_brackets
ORDER BY discount_brackets DESC;

-- 10. Business Question: What percentage of total orders result in returns or cancellations, 
-- and which product categories or cities exhibit the highest return rates?
SELECT
    p.Category,
    s.City,
    COUNT(s.Order_ID) AS total_orders,
    
    -- Delivered
    SUM(CASE WHEN s.Order_Status = 'Delivered' THEN 1 ELSE 0 END) AS total_delivered_orders,
    
    -- Returned
    SUM(CASE WHEN s.Order_Status = 'Returned' THEN 1 ELSE 0 END) AS total_returned_orders,
    ROUND((SUM(CASE WHEN s.Order_Status = 'Returned' THEN 1 ELSE 0 END) * 100.0) / COUNT(s.Order_ID), 2) AS return_rate_pct,
    
    -- Cancelled
    SUM(CASE WHEN s.Order_Status = 'Cancelled' THEN 1 ELSE 0 END) AS total_cancelled_orders,
    ROUND((SUM(CASE WHEN s.Order_Status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0) / COUNT(s.Order_ID), 2) AS cancelled_rate_pct

FROM products AS p
INNER JOIN sales AS s
    ON p.Product_ID = s.Product_ID
GROUP BY p.Category, s.City
ORDER BY return_rate_pct DESC;

-- 11. Business Question: What is the average delivery lead time (days between Order_Date and Delivery_Date), 
-- and does longer delivery time correlate with lower customer ratings?
WITH cte AS
(
SELECT
	Rating,
	DATEDIFF(Delivery_Date, Order_Date) AS days_delivered
FROM sales
WHERE Order_Status = 'Delivered'
)
SELECT
	CASE 
		WHEN days_delivered <= 3 THEN "1-3 Days"
		WHEN days_delivered BETWEEN 4 AND 5 THEN "4-5 Days"
		ELSE "6+ Days"
	END AS delivery_duration,
    COUNT(*) As total_delivered_orders,
    ROUND(AVG(days_delivered),2) AS avg_lead_time,
    ROUND(AVG(Rating),2) AS avg_rating
FROM cte
GROUP BY delivery_duration;

-- 12. What is the breakdown of preferred payment modes (COD, UPI, Credit Card, Debit Card),
-- and do digital payment methods have higher average transaction values than Cash on Delivery?
SELECT
	Payment_Mode,
    COUNT(Order_ID) AS total_order,
    SUM(Total_Amount) AS total_revenue,
    ROUND(AVG(Total_Amount),2) AS avg_order_value
FROM sales
WHERE Order_Status = 'Delivered'
GROUP BY Payment_Mode
ORDER BY avg_order_value DESC;
```

## 📊 Interactive Dashboards
### 1. Executive Sales Dashboard
<img width="775" height="439" alt="image" src="https://github.com/user-attachments/assets/b2387647-754d-44ba-9340-cbaf575bde1f" />

### 2. Operations, Customer & Inventory Deep Dive
<img width="772" height="437" alt="image" src="https://github.com/user-attachments/assets/d26ba093-fbbd-4c8c-aeb4-4664f5c0e0e7" />

> 🔗 **Power BI File:** [Download the e_commerce_dax_and_dashboard.pbix report](./e_commerce_dax_and_dashboard.pbix)

### Key Findings & Strategic Recommendations

#### 1. **Customer Tier Revenue Concentration (Platinum Dominance)**
* Finding: The Platinum tier drives an overwhelming 93.96% of total platform revenue (₹4,455,365,020.47 out of ₹4,741,566,354.41) with an average spend of ₹162,907.79 per customer and an average order frequency of 5.61 orders. In contrast, Silver and Gold tiers contribute minor shares of 1.13% and 4.90% respectively.   

* Recommendation: Implement exclusive VIP loyalty programs, personalized perks, and early-access promotions tailored specifically for Platinum customers to protect core revenue, while creating structured upselling campaigns to transition Silver and Gold buyers into higher tiers.

#### **2. Payment Mode Preferences & Transaction Value**
* Finding: While UPI dominates total order volume (102,846 orders generating ₹2.53 Billion), Credit Cards yield the highest Average Order Value at ₹26,341.72, followed closely by UPI at ₹24,688.87. Cash on Delivery (COD) commands 65,679 orders with a lower average order value of ₹22,459.25.   

* Recommendation: Encourage the adoption of higher-value digital payment methods (such as Credit Cards and UPI) through strategic checkout discounts or reward incentives to maximize basket sizes and mitigate the financial risks associated with Cash on Delivery.

#### **3. Product Category & Brand Revenue Concentration**
* Finding: Electronics (featuring top brands like HP, Noise, boAt, Samsung, and Apple) overwhelmingly dominate both sales volume and revenue generation across the platform. Specifically, HP leads brand revenue at over ₹754 Million, with Noise closely following at ₹729 Million.   

* Recommendation: Form strategic vendor partnerships and secure priority stock allocations with leading electronic brands (HP, Noise, boAt) to prevent stockouts and safeguard the platform's primary revenue stream.

#### **4. Impact of Discount Brackets on Sales Volume and Ratings**
* Finding: An analysis across discount brackets (0–10%, 11–25%, and 26–50%) demonstrates that deep discounts (26–50%) and low discounts (0–10%) yield virtually identical average customer ratings (4.40 vs 4.41) and nearly identical average quantities per order (~1.25). Steep discounting does not trigger significantly larger order quantities per transaction, nor does it negatively impact product ratings.

*Recommendation: Optimize promotional budgets by moving away from broad, deep price cuts (26–50%) across all products; instead, utilize targeted bundle deals and loyalty-exclusive discounts to protect profit margins without sacrificing perceived product quality.

#### **5. Geographic Sales Distribution & Regional Hubs**
* Finding: Top-performing cities and states—such as Madurai (Tamil Nadu), New Delhi, Howrah (West Bengal), Kanpur, and Varanasi (Uttar Pradesh)—consistently drive the highest customer counts, order volumes, and total revenues (ranging between ₹1.24 Billion and ₹1.36 Billion per top geographic grouping).

* Recommendation: Streamline supply chain logistics and establish regional fulfillment hubs or dark warehouses in high-density areas (such as Uttar Pradesh, Delhi, and Tamil Nadu) to minimize transit times and enhance customer delivery experiences. 
