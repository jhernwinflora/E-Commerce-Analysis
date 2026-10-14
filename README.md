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
SET Coupon_Code = 'No coupon used' 
WHERE Coupon_Code IS NULL OR Coupon_Code = '';

UPDATE sales 
SET Review_Text = 'No written review left' 
WHERE Review_Text IS NULL OR Review_Text = '';
```
