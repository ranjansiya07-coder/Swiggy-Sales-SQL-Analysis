# Swiggy Sales & Customer Insights SQL Project

## Project Overview

**Project Title**: Swiggy Sales & Customer Insights Analysis  
**Level**: Fresher / Beginner Portfolio Project  
**Database**: SQL Server (`swiggy Database`)

This project demonstrates SQL skills commonly used by Data Analysts to explore, clean, model, and analyze Swiggy-style food delivery sales data.  
The project includes data validation, duplicate removal, star schema creation (dimensional modeling), KPI reporting, business analysis, and advanced SQL window functions.

---

## Objectives

1. **Dataset Setup**: Import food delivery dataset into SQL Server.
2. **Data Cleaning**: Validate dataset and remove duplicates.
3. **Data Modelling (Star Schema)**: Convert raw data into dimensions and fact tables.
4. **KPI Reporting**: Generate business KPIs like orders, revenue, ratings.
5. **Business Analysis**: Answer business questions using SQL queries.
6. **Advanced SQL**: Use window functions for ranking and running totals.

---

## Dataset Information

Raw table used:
- `swiggy_data`

Dataset contains columns like:
- State, City, Location
- Restaurant Name
- Category
- Dish Name
- Price (INR)
- Rating, Rating Count
- Order Date

---

## Project Structure

### 1. Data Validation & Cleaning

**NULL Validation**
```sql
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
```

**Blank / Empty Value Validation**
```sql
SELECT *
FROM swiggy_data
WHERE
    State = '' OR City = '' OR Restaurant_Name = '' OR Location = '' OR Category = '' OR Dish_Name = '';
```

**Duplicate Detection**
```sql
SELECT 
    State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name,
    Price__INR_, Rating, Rating_Count,
    COUNT(*) AS duplicate_count
FROM swiggy_data
GROUP BY 
    State, City, Order_Date, Restaurant_Name, Location, Category, Dish_Name,
    Price__INR_, Rating, Rating_Count
HAVING COUNT(*) > 1;
```

**Duplicate Removal using Window Function**
```sql
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
```

### 2) Star Schema (Dimensional Modelling)

The raw dataset was transformed into a Star Schema for analysis.

✅ Dimension Tables:

- dim_date
- dim_location
- dim_restaurant
- dim_category
- dim_dish

✅ Fact Table:

- fact_swiggy_orders

This model helps in efficient analytics using joins and aggregation queries.



### Star Schema Design
![Star Schema](star_schema.png)




### 3) KPI Reporting

**Total Orders**
```sql
SELECT COUNT(*) AS Total_Orders
FROM fact_swiggy_orders;
```

**Total Revenue (INR Million)**
```sql
SELECT 
    FORMAT(SUM(CONVERT(FLOAT, Price_INR)) / 1000000, 'N2') + ' INR Million' AS Total_Revenue
FROM fact_swiggy_orders;
```

**Average Dish Price**
```sql
SELECT 
    FORMAT(AVG(CONVERT(FLOAT, Price_INR)), 'N2') + ' INR' AS Avg_Dish_Price
FROM fact_swiggy_orders;
```

**Average Rating**
```sql
SELECT AVG(Rating) AS Avg_Rating
FROM fact_swiggy_orders;
```

### 4) Business Analysis Queries

**Monthly Orders Trend**
```sql
SELECT 
    d.Year,
    d.Month,
    d.Month_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id = d.Date_Id
GROUP BY d.Year, d.Month, d.Month_Name
ORDER BY d.Year, d.Month;
```

**Quarterly Orders Trend**
```sql
SELECT 
    d.Year,
    d.Quarter,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id = d.Date_Id
GROUP BY d.Year, d.Quarter
ORDER BY d.Year, d.Quarter;
```

**Yearly Orders Trend**
```sql
SELECT 
    d.Year,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id = d.Date_Id
GROUP BY d.Year
ORDER BY d.Year;
```

**Orders by Day of Week (Mon–Sun)**
```sql
SELECT 
    DATENAME(WEEKDAY, d.Full_Date) AS day_name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id = d.Date_Id
GROUP BY DATENAME(WEEKDAY, d.Full_Date), DATEPART(WEEKDAY, d.Full_Date)
ORDER BY DATEPART(WEEKDAY, d.Full_Date);
```

**Top 10 Cities by Orders**
```sql
SELECT TOP 10
    l.City,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_location l ON l.Location_Id = f.Location_Id
GROUP BY l.City
ORDER BY COUNT(*) DESC;
```

**Revenue Contribution by State**
```sql
SELECT 
    l.State,
    SUM(f.Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_location l ON l.Location_Id = f.Location_Id
GROUP BY l.State
ORDER BY SUM(f.Price_INR) DESC;
```

**Top 10 Restaurants by Orders**
```sql
SELECT TOP 10
    r.Restaurant_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r ON r.Restaurant_Id = f.Restaurant_Id
GROUP BY r.Restaurant_Name
ORDER BY COUNT(*) DESC;
```

**Top Categories by Orders**
```sql
SELECT 
    c.Category,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c ON c.Category_Id = f.Category_Id
GROUP BY c.Category
ORDER BY COUNT(*) DESC;
```

**Most Ordered Dishes**
```sql
SELECT TOP 10
    di.Dish_Name,
    COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_dish di ON di.Dish_Id = f.Dish_Id
GROUP BY di.Dish_Name
ORDER BY COUNT(*) DESC;
```

**Cuisine Performance (Orders + Avg Rating)**
```sql
SELECT 
    c.Category,
    COUNT(*) AS Total_Orders,
    AVG(f.Rating) AS Avg_Rating
FROM fact_swiggy_orders f
JOIN dim_category c ON c.Category_Id = f.Category_Id
GROUP BY c.Category
ORDER BY Total_Orders DESC;
```

**Orders by Price Range**
```sql
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
```

**Rating Distribution**
```sql
SELECT
    Rating,
    COUNT(*) AS rating_count
FROM fact_swiggy_orders
GROUP BY Rating
ORDER BY COUNT(*) DESC;
```

### Advanced SQL (Window Functions)

**Top 3 Restaurants in Each City**
```sql
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
    JOIN dim_location l ON l.Location_Id = f.Location_Id
    JOIN dim_restaurant r ON r.Restaurant_Id = f.Restaurant_Id
    GROUP BY l.City, r.Restaurant_Name
)
SELECT *
FROM city_restaurant
WHERE rn <= 3
ORDER BY City, total_orders DESC;
```

**Top 5 Dishes in Each Category**
```sql
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
    JOIN dim_category c ON c.Category_Id = f.Category_Id
    JOIN dim_dish di ON di.Dish_Id = f.Dish_Id
    GROUP BY c.Category, di.Dish_Name
)
SELECT *
FROM dish_perf
WHERE rnk <= 5
ORDER BY Category, total_orders DESC;
```

**Running Total Revenue (Month-wise)**
```sql
WITH monthly_revenue AS (
    SELECT
        d.Year,
        d.Month,
        d.Month_Name,
        SUM(f.Price_INR) AS total_revenue
    FROM fact_swiggy_orders f
    JOIN dim_date d ON d.Date_Id = d.Date_Id
    GROUP BY d.Year, d.Month, d.Month_Name
)
SELECT *,
       SUM(total_revenue) OVER (ORDER BY Year, Month) AS running_total_revenue
FROM monthly_revenue
ORDER BY Year, Month;
```

### Findings / Insights

- Identified top-performing cities and restaurants based on order volume.
- Found categories and dishes contributing the highest orders.
- Analyzed customer spending patterns using price range buckets.
- Studied rating distribution and cuisine performance.
- Used window functions for ranking and revenue tracking.

### How to Use

- Import dataset into SQL Server table: swiggy_data
- Run the SQL script file in SSMS:
    Swiggy_Sales_Project.sql
- Execute KPI and analysis queries.

### Author
Ranjan Shekar Siya
(Fresher Data Analyst Portfolio Project)
