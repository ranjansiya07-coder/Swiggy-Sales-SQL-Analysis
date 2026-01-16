/*==========================================================
  SWIGGY SALES & CUSTOMER INSIGHTS PROJECT (SQL SERVER)
  - Data Validation & Cleaning
  - Star Schema Design (Dim + Fact)
  - KPI Reporting
  - Deep Dive Analysis
  - Advanced Window Function Analysis
==========================================================*/

/*===========================================================
	CREATE DATABASE
	===========================================================*/
CREATE DATABASE swiggy_Database
GO

/* ===============================================================
	USE DATABASE
	============================================================*/
USE [swiggy Database];
GO

------------------------------------------------------------
-- 0) QUICK VIEW 
------------------------------------------------------------
SELECT TOP 100 * 
FROM swiggy_data;
GO

/*==========================================================
  1) DATA VALIDATION & CLEANING
==========================================================*/

------------------------------------------------------------
-- 1.1 NULL CHECK (Column-wise)
------------------------------------------------------------
SELECT 
    SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
    SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN Order_Date IS NULL THEN 1 ELSE 0 END) AS null_order_date,
    SUM(CASE WHEN Restaurant_Name IS NULL THEN 1 ELSE 0 END) AS null_restaurant,
    SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
    SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dish,
    SUM(CASE WHEN Price__INR_ IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
    SUM(CASE WHEN Rating_Count IS NULL THEN 1 ELSE 0 END) AS null_rating_count
FROM swiggy_data;
GO

------------------------------------------------------------
-- 1.2 BLANK / EMPTY STRING CHECK
------------------------------------------------------------
SELECT *
FROM swiggy_data
WHERE
    State = '' OR City = '' OR Restaurant_Name = '' OR Location = '' OR Category = '' OR Dish_Name = '';
GO

------------------------------------------------------------
-- 1.3 DUPLICATE DETECTION
------------------------------------------------------------
SELECT 
    State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name,
    Price__INR_, Rating, Rating_Count,
    COUNT(*) AS duplicate_count
FROM swiggy_data
GROUP BY 
    State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name,
    Price__INR_, Rating, Rating_Count
HAVING COUNT(*) > 1;
GO

------------------------------------------------------------
-- 1.4 REMOVE DUPLICATES USING ROW_NUMBER()
------------------------------------------------------------
WITH CTE AS (
    SELECT *,
        ROW_NUMBER() OVER(
            PARTITION BY State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name,
                         Price__INR_, Rating, Rating_Count
            ORDER BY (SELECT NULL)
        ) AS rn
    FROM swiggy_data
)
DELETE FROM CTE
WHERE rn > 1;
GO


/*==========================================================
  2) STAR SCHEMA CREATION (DIMENSION + FACT TABLES)
==========================================================*/

------------------------------------------------------------
-- 2.1 DROP TABLES IF RE-RUNNING SCRIPT (SAFE RESET)
------------------------------------------------------------
DROP TABLE IF EXISTS fact_swiggy_orders;
DROP TABLE IF EXISTS dim_dish;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_restaurant;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_date;
GO

------------------------------------------------------------
-- 2.2 CREATE DIMENSION TABLES
------------------------------------------------------------

-- DATE DIMENSION
CREATE TABLE dim_date (
    Date_Id INT IDENTITY(1,1) PRIMARY KEY,
    Full_Date DATE,
    Year INT,
    Month INT,
    Month_Name VARCHAR(20),
    Quarter INT,
    Week INT,
    Day INT
);
GO

-- LOCATION DIMENSION
CREATE TABLE dim_location (
    Location_Id INT IDENTITY(1,1) PRIMARY KEY,
    State VARCHAR(100),
    City VARCHAR(100),
    Location VARCHAR(200)
);
GO

-- RESTAURANT DIMENSION
CREATE TABLE dim_restaurant (
    Restaurant_Id INT IDENTITY(1,1) PRIMARY KEY,
    Restaurant_Name VARCHAR(200)
);
GO

-- CATEGORY DIMENSION
CREATE TABLE dim_category (
    Category_Id INT IDENTITY(1,1) PRIMARY KEY,
    Category VARCHAR(200)
);
GO

-- DISH DIMENSION
CREATE TABLE dim_dish (
    Dish_Id INT IDENTITY(1,1) PRIMARY KEY,
    Dish_Name VARCHAR(200)
);
GO

------------------------------------------------------------
-- 2.3 CREATE FACT TABLE
------------------------------------------------------------
CREATE TABLE fact_swiggy_orders (
    Order_Id INT IDENTITY(1,1) PRIMARY KEY,

    Date_Id INT,
    Price_INR DECIMAL(10,2),
    Rating DECIMAL(4,2),
    Rating_Count INT,

    Location_Id INT,
    Restaurant_Id INT,
    Category_Id INT,
    Dish_Id INT,

    CONSTRAINT fk_fact_date       FOREIGN KEY (Date_Id) REFERENCES dim_date(Date_Id),
    CONSTRAINT fk_fact_location   FOREIGN KEY (Location_Id) REFERENCES dim_location(Location_Id),
    CONSTRAINT fk_fact_restaurant FOREIGN KEY (Restaurant_Id) REFERENCES dim_restaurant(Restaurant_Id),
    CONSTRAINT fk_fact_category   FOREIGN KEY (Category_Id) REFERENCES dim_category(Category_Id),
    CONSTRAINT fk_fact_dish       FOREIGN KEY (Dish_Id) REFERENCES dim_dish(Dish_Id)
);
GO


/*==========================================================
  3) INSERT DATA INTO DIMENSION TABLES
==========================================================*/

------------------------------------------------------------
-- 3.1 INSERT INTO dim_date  ? FIXED Week/Day order + Quarter
------------------------------------------------------------
INSERT INTO dim_date (Full_Date, Year, Month, Month_Name, Quarter, Week, Day)
SELECT DISTINCT
    Order_Date,
    YEAR(Order_Date),
    MONTH(Order_Date),
    DATENAME(MONTH, Order_Date),
    DATEPART(QUARTER, Order_Date),
    DATEPART(WEEK, Order_Date),
    DAY(Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;
GO

------------------------------------------------------------
-- 3.2 INSERT INTO dim_location
------------------------------------------------------------
INSERT INTO dim_location (State, City, Location)
SELECT DISTINCT
    State, City, Location
FROM swiggy_data;
GO

------------------------------------------------------------
-- 3.3 INSERT INTO dim_restaurant
------------------------------------------------------------
INSERT INTO dim_restaurant (Restaurant_Name)
SELECT DISTINCT
    Restaurant_Name
FROM swiggy_data;
GO

------------------------------------------------------------
-- 3.4 INSERT INTO dim_category
------------------------------------------------------------
INSERT INTO dim_category (Category)
SELECT DISTINCT
    Category
FROM swiggy_data;
GO

------------------------------------------------------------
-- 3.5 INSERT INTO dim_dish
------------------------------------------------------------
INSERT INTO dim_dish (Dish_Name)
SELECT DISTINCT
    Dish_Name
FROM swiggy_data;
GO


/*==========================================================
  4) INSERT DATA INTO FACT TABLE
==========================================================*/

INSERT INTO fact_swiggy_orders
(
    Date_Id,
    Price_INR,
    Rating,
    Rating_Count,
    Location_Id,
    Restaurant_Id,
    Category_Id,
    Dish_Id
)
SELECT
    dd.Date_Id,
    s.Price__INR_,
    s.Rating,
    s.Rating_Count,

    dl.Location_Id,
    dr.Restaurant_Id,
    dc.Category_Id,
    dsh.Dish_Id
FROM swiggy_data s
JOIN dim_date dd
    ON dd.Full_Date = s.Order_Date
JOIN dim_location dl
    ON dl.State = s.State
    AND dl.City = s.City
    AND dl.Location = s.Location
JOIN dim_restaurant dr
    ON dr.Restaurant_Name = s.Restaurant_Name
JOIN dim_category dc
    ON dc.Category = s.Category
JOIN dim_dish dsh
    ON dsh.Dish_Name = s.Dish_Name;
GO


/*==========================================================
  5) KPI REPORTING
==========================================================*/

------------------------------------------------------------
-- KPI 1: Total Orders
------------------------------------------------------------
SELECT COUNT(*) AS Total_Orders
FROM fact_swiggy_orders;
GO

------------------------------------------------------------
-- KPI 2: Total Revenue (INR Million)
------------------------------------------------------------
SELECT 
    FORMAT(SUM(CONVERT(FLOAT, Price_INR)) / 1000000, 'N2') + ' INR Million' AS Total_Revenue
FROM fact_swiggy_orders;
GO

------------------------------------------------------------
-- KPI 3: Average Dish Price
------------------------------------------------------------
SELECT 
    FORMAT(AVG(CONVERT(FLOAT, Price_INR)), 'N2') + ' INR' AS Avg_Dish_Price
FROM fact_swiggy_orders;
GO

------------------------------------------------------------
-- KPI 4: Average Rating
------------------------------------------------------------
SELECT AVG(Rating) AS Avg_Rating
FROM fact_swiggy_orders;
GO


/*==========================================================
  6) DEEP DIVE BUSINESS ANALYSIS
==========================================================*/

------------------------------------------------------------
-- 6.1 Monthly Order Trends (Proper trend order)
------------------------------------------------------------
SELECT 
    d.Year,
    d.Month,
    d.Month_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.Date_Id = d.Date_Id
GROUP BY d.Year, d.Month, d.Month_Name
ORDER BY d.Year, d.Month;
GO

------------------------------------------------------------
-- 6.2 Quarterly Order Trends
------------------------------------------------------------
SELECT 
    d.Year,
    d.Quarter,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.Date_Id = d.Date_Id
GROUP BY d.Year, d.Quarter
ORDER BY d.Year, d.Quarter;
GO

------------------------------------------------------------
-- 6.3 Yearly Order Trends
------------------------------------------------------------
SELECT 
    d.Year,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.Date_Id = d.Date_Id
GROUP BY d.Year
ORDER BY d.Year;
GO

------------------------------------------------------------
-- 6.4 Orders by Day of Week (Mon-Sun)
------------------------------------------------------------
SELECT 
    DATENAME(WEEKDAY, d.Full_Date) AS day_name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
    ON f.Date_Id = d.Date_Id
GROUP BY DATENAME(WEEKDAY, d.Full_Date), DATEPART(WEEKDAY, d.Full_Date)
ORDER BY DATEPART(WEEKDAY, d.Full_Date);
GO

------------------------------------------------------------
-- 6.5 Top 10 Cities by Order Volume
------------------------------------------------------------
SELECT TOP 10
    l.City,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_location l
    ON l.Location_Id = f.Location_Id
GROUP BY l.City
ORDER BY COUNT(*) DESC;
GO

------------------------------------------------------------
-- 6.6 Revenue Contribution by State
------------------------------------------------------------
SELECT 
    l.State,
    SUM(f.Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_location l
    ON l.Location_Id = f.Location_Id
GROUP BY l.State
ORDER BY SUM(f.Price_INR) DESC;
GO

------------------------------------------------------------
-- 6.7 Top 10 Restaurants by Orders
------------------------------------------------------------
SELECT TOP 10
    r.Restaurant_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r
    ON r.Restaurant_Id = f.Restaurant_Id
GROUP BY r.Restaurant_Name
ORDER BY COUNT(*) DESC;
GO

------------------------------------------------------------
-- 6.8 Top Categories by Order Volume
------------------------------------------------------------
SELECT 
    c.Category,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c
    ON c.Category_Id = f.Category_Id
GROUP BY c.Category
ORDER BY COUNT(*) DESC;
GO

------------------------------------------------------------
-- 6.9 Most Ordered Dishes (Top 10)
------------------------------------------------------------
SELECT TOP 10
    di.Dish_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_dish di
    ON di.Dish_Id = f.Dish_Id
GROUP BY di.Dish_Name
ORDER BY COUNT(*) DESC;
GO

------------------------------------------------------------
-- 6.10 Cuisine Performance (Orders + Avg Rating)
------------------------------------------------------------
SELECT 
    c.Category,
    COUNT(*) AS Total_Orders,
    AVG(f.Rating) AS Avg_Rating
FROM fact_swiggy_orders f
JOIN dim_category c
    ON c.Category_Id = f.Category_Id
GROUP BY c.Category
ORDER BY Total_Orders DESC;
GO

------------------------------------------------------------
-- 6.11 Total Orders by Price Range
------------------------------------------------------------
SELECT
    CASE 
        WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
        ELSE '500+'
    END AS price_range,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders
GROUP BY
    CASE 
        WHEN CONVERT(FLOAT, Price_INR) < 100 THEN 'Under 100'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
        WHEN CONVERT(FLOAT, Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
        ELSE '500+'
    END
ORDER BY Total_Orders DESC;
GO

------------------------------------------------------------
-- 6.12 Rating Distribution
------------------------------------------------------------
SELECT
    Rating,
    COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY Rating
ORDER BY COUNT(*) DESC;
GO


/*==========================================================
  7) ADVANCED ANALYSIS USING WINDOW FUNCTIONS
==========================================================*/

------------------------------------------------------------
-- 7.1 Top 3 Restaurants in each City (ROW_NUMBER)
------------------------------------------------------------
WITH city_restaurant AS (
    SELECT
        l.City,
        r.Restaurant_Name,
        COUNT(*) AS total_orders,
        ROW_NUMBER() OVER (
            PARTITION BY l.City
            ORDER BY COUNT(*) DESC
        ) AS rn
    FROM fact_swiggy_orders f
    JOIN dim_location l 
        ON l.Location_Id = f.Location_Id
    JOIN dim_restaurant r 
        ON r.Restaurant_Id = f.Restaurant_Id
    GROUP BY l.City, r.Restaurant_Name
)
SELECT *
FROM city_restaurant
WHERE rn <= 3
ORDER BY City, total_orders DESC;
GO

------------------------------------------------------------
-- 7.2 Category-wise Top 5 Dishes (DENSE_RANK)
------------------------------------------------------------
WITH dish_perf AS (
    SELECT
        c.Category,
        di.Dish_Name,
        COUNT(*) AS total_orders,
        DENSE_RANK() OVER (
            PARTITION BY c.Category
            ORDER BY COUNT(*) DESC
        ) AS rnk
    FROM fact_swiggy_orders f
    JOIN dim_category c 
        ON c.Category_Id = f.Category_Id
    JOIN dim_dish di 
        ON di.Dish_Id = f.Dish_Id
    GROUP BY c.Category, di.Dish_Name
)
SELECT *
FROM dish_perf
WHERE rnk <= 5
ORDER BY Category, total_orders DESC;
GO

------------------------------------------------------------
-- 7.3 Running Total Revenue Month-wise (SUM OVER)
------------------------------------------------------------
WITH monthly_revenue AS (
    SELECT
        d.Year,
        d.Month,
        d.Month_Name,
        SUM(f.Price_INR) AS total_revenue
    FROM fact_swiggy_orders f
    JOIN dim_date d 
        ON d.Date_Id = f.Date_Id
    GROUP BY d.Year, d.Month, d.Month_Name
)
SELECT *,
       SUM(total_revenue) OVER (ORDER BY Year, Month) AS running_total_revenue
FROM monthly_revenue
ORDER BY Year, Month;
GO