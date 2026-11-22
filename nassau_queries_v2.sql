USE nassau;
SELECT COUNT(*) FROM orders_raw;
/* =====================================================================
   Nassau Candy: Factory-to-Customer Shipping Route Efficiency Analysis
   File: nassau_queries_v2.sql   (database: nassau, SQL Server)
   Order matters: run the sections from top to bottom.
   ===================================================================== */

/* ---- 1. Import (done with SSMS Import Flat File) ----
   The CSV was imported into table orders_raw (10194 rows, 18 columns).
   Order_Date, Ship_Date and Postal_Code were kept as text (nvarchar).
   Date format in the file is dd-mm-yyyy.
*/

USE nassau;
GO

/* ---- 2. View with real dates and raw lead time ---- */
CREATE OR ALTER VIEW orders_dates AS
SELECT
    *,
    TRY_CONVERT(date, Order_Date, 105) AS Order_Dt,   -- 105 = dd-mm-yyyy
    TRY_CONVERT(date, Ship_Date, 105) AS Ship_Dt,
    DATEDIFF(day, TRY_CONVERT(date, Order_Date, 105), TRY_CONVERT(date, Ship_Date, 105)) AS Lead_Time
FROM orders_raw;
GO

/* ---- 3. Cleaning: remove duplicates, round money columns ----
   Duplicate = all columns equal except Row_ID. Canada rows are kept here
   and filtered out later (US-only analysis). */
DROP TABLE IF EXISTS orders_clean;
GO

WITH numbered AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY Order_ID, Order_Date, Ship_Date, Ship_Mode, Customer_ID,
                         Country_Region, City, State_Province, Postal_Code, Division,
                         Region, Product_ID, Product_Name, Sales, Units, Gross_Profit, Cost
            ORDER BY Row_ID
        ) AS rn
    FROM orders_dates
)
SELECT
    Row_ID, Order_ID, Order_Dt, Ship_Dt, Ship_Mode, Customer_ID,
    Country_Region, City, State_Province, Postal_Code, Division, Region,
    Product_ID, Product_Name,
    CAST(ROUND(Sales, 2) AS DECIMAL(10,2)) AS Sales,
    Units,
    CAST(ROUND(Gross_Profit, 2) AS DECIMAL(10,2)) AS Gross_Profit,
    CAST(ROUND(Cost, 2) AS DECIMAL(10,2)) AS Cost,
    Lead_Time
INTO orders_clean
FROM numbered
WHERE rn = 1;
GO

/* ---- 4. Lead time adjustment (ASSUMPTION, see report) ----
   Raw lead times are 904 to 1642 days because the dates in the dataset carry
   whole-year offsets. Shift_Group = number of whole-year offsets (0, 1 or 2).
   Group 2 (Order_ID year 2024) carries one extra day (leap year 2028), so one
   day is subtracted. Negative values (3 rows) are set to 0. */
ALTER TABLE orders_clean ADD Shift_Group INT, Lead_Time_Adj INT;
GO

UPDATE orders_clean SET Shift_Group = (Lead_Time - 904) / 365;

UPDATE orders_clean
SET Lead_Time_Adj = ((Lead_Time - 904) % 365) - CASE WHEN Shift_Group = 2 THEN 1 ELSE 0 END;

UPDATE orders_clean SET Lead_Time_Adj = 0 WHERE Lead_Time_Adj < 0;
GO

/* ---- 5. Factory tables (from the project page) ---- */
DROP TABLE IF EXISTS factory_map;
DROP TABLE IF EXISTS factory_coords;
GO

CREATE TABLE factory_map (
    Division NVARCHAR(20),
    Product_Name NVARCHAR(100),
    Factory NVARCHAR(50)
);

INSERT INTO factory_map (Division, Product_Name, Factory) VALUES
('Chocolate', 'Wonka Bar - Nutty Crunch Surprise', 'Lot''s O'' Nuts'),
('Chocolate', 'Wonka Bar - Fudge Mallows', 'Lot''s O'' Nuts'),
('Chocolate', 'Wonka Bar -Scrumdiddlyumptious', 'Lot''s O'' Nuts'),
('Chocolate', 'Wonka Bar - Milk Chocolate', 'Wicked Choccy''s'),
('Chocolate', 'Wonka Bar - Triple Dazzle Caramel', 'Wicked Choccy''s'),
('Sugar', 'Laffy Taffy', 'Sugar Shack'),
('Sugar', 'SweeTARTS', 'Sugar Shack'),
('Sugar', 'Nerds', 'Sugar Shack'),
('Sugar', 'Fun Dip', 'Sugar Shack'),
('Other', 'Fizzy Lifting Drinks', 'Sugar Shack'),
('Sugar', 'Everlasting Gobstopper', 'Secret Factory'),
('Sugar', 'Hair Toffee', 'The Other Factory'),
('Other', 'Lickable Wallpaper', 'Secret Factory'),
('Other', 'Wonka Gum', 'Secret Factory'),
('Other', 'Kazookles', 'The Other Factory');

CREATE TABLE factory_coords (
    Factory NVARCHAR(50),
    Latitude DECIMAL(9,6),
    Longitude DECIMAL(9,6)
);

INSERT INTO factory_coords (Factory, Latitude, Longitude) VALUES
('Lot''s O'' Nuts', 32.881893, -111.768036),
('Wicked Choccy''s', 32.076176, -81.088371),
('Sugar Shack', 48.11914, -96.18115),
('Secret Factory', 41.446333, -90.565487),
('The Other Factory', 35.1175, -89.971107);
GO

/* ---- 6A. orders_routes: US orders with Factory and Route ---- */
DROP TABLE IF EXISTS orders_routes;
DROP TABLE IF EXISTS route_summary;
DROP TABLE IF EXISTS route_kpis;
DROP TABLE IF EXISTS state_summary;
GO

SELECT
    o.Row_ID, o.Order_ID, o.Order_Dt, o.Ship_Dt, o.Ship_Mode, o.Customer_ID,
    o.City, o.State_Province, o.Region, o.Product_ID, o.Product_Name,
    f.Division AS Division_Ref,
    f.Factory,
    f.Factory + ' -> ' + o.State_Province AS Route,
    o.Sales, o.Units, o.Gross_Profit, o.Cost,
    o.Lead_Time, o.Lead_Time_Adj
INTO orders_routes
FROM orders_clean o
JOIN factory_map f ON o.Product_Name = f.Product_Name
WHERE o.Country_Region = 'United States';
GO

/* ---- 6B. route_kpis: one row per route (delay threshold = 6 days) ---- */
SELECT
    Factory, State_Province, Route,
    COUNT(*) AS shipments,
    ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time,
    ROUND(STDEV(Lead_Time_Adj * 1.0), 2) AS lead_time_std,
    SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(100.0 * SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_pct,
    ROUND(100.0 * SUM(CASE WHEN Ship_Mode = 'Standard Class' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_standard
INTO route_kpis
FROM orders_routes
GROUP BY Factory, State_Province, Route;
GO

/* Efficiency score: min-max scaling, 100 = fastest, 0 = slowest.
   Only routes with 10 or more shipments get a score. */
ALTER TABLE route_kpis ADD efficiency_score DECIMAL(5,1);
GO

UPDATE r
SET efficiency_score = 100.0 * (b.max_avg - r.avg_lead_time) / (b.max_avg - b.min_avg)
FROM route_kpis r
CROSS JOIN (
    SELECT MIN(avg_lead_time) AS min_avg, MAX(avg_lead_time) AS max_avg
    FROM route_kpis
    WHERE shipments >= 10
) b
WHERE r.shipments >= 10;
GO

/* ---- 6C. state_summary: one row per US state ---- */
SELECT
    State_Province,
    MAX(Region) AS Region,
    COUNT(*) AS orders,
    ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time,
    ROUND(STDEV(Lead_Time_Adj * 1.0), 2) AS lead_time_std,
    SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(100.0 * SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_pct,
    ROUND(100.0 * SUM(CASE WHEN Ship_Mode = 'Standard Class' THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_standard,
    ROUND(AVG(CASE WHEN Ship_Mode = 'Standard Class' THEN Lead_Time_Adj * 1.0 END), 2) AS std_class_avg_lead
INTO state_summary
FROM orders_routes
GROUP BY State_Province;
GO

/* Bottleneck = 100+ orders AND average lead time above the US average */
ALTER TABLE state_summary ADD status VARCHAR(20);
GO

UPDATE state_summary
SET status = CASE
    WHEN orders >= 100 AND avg_lead_time > (SELECT AVG(Lead_Time_Adj * 1.0) FROM orders_routes) THEN 'Bottleneck'
    WHEN orders >= 100 THEN 'Normal'
    ELSE 'Low volume'
END;
GO

/* ---- 7. Analysis queries (run one at a time) ---- */

/* 7a. Ship mode comparison */
SELECT
    Ship_Mode,
    COUNT(*) AS orders,
    ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time,
    ROUND(STDEV(Lead_Time_Adj * 1.0), 2) AS lead_time_std,
    MIN(Lead_Time_Adj) AS min_lead,
    MAX(Lead_Time_Adj) AS max_lead,
    ROUND(100.0 * SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_pct
FROM orders_routes
GROUP BY Ship_Mode
ORDER BY avg_lead_time;

/* 7b. Top 10 fastest routes (10+ shipments) */
SELECT TOP 10 Route, shipments, avg_lead_time, delay_pct, pct_standard, efficiency_score
FROM route_kpis
WHERE shipments >= 10
ORDER BY avg_lead_time;

/* 7c. Top 10 slowest routes (10+ shipments) */
SELECT TOP 10 Route, shipments, avg_lead_time, delay_pct, pct_standard, efficiency_score
FROM route_kpis
WHERE shipments >= 10
ORDER BY avg_lead_time DESC;

/* 7d. Routes inside Standard Class only (removes the ship mode effect) */
SELECT TOP 5 Route, COUNT(*) AS standard_orders,
       ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time
FROM orders_routes
WHERE Ship_Mode = 'Standard Class'
GROUP BY Route
HAVING COUNT(*) >= 10
ORDER BY avg_lead_time;         

SELECT TOP 5 Route, COUNT(*) AS standard_orders,
       ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time
FROM orders_routes
WHERE Ship_Mode = 'Standard Class'
GROUP BY Route
HAVING COUNT(*) >= 10
ORDER BY avg_lead_time desc ;    -- add DESC for the slowest 5

/* 7e. Bottleneck states */
SELECT State_Province, orders, avg_lead_time, std_class_avg_lead, delay_pct
FROM state_summary
WHERE status = 'Bottleneck'
ORDER BY avg_lead_time DESC;

/* 7f. Region comparison */
SELECT Region, COUNT(*) AS orders,
       ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS avg_lead_time,
       ROUND(100.0 * SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) / COUNT(*), 1) AS delay_pct
FROM orders_routes
GROUP BY Region
ORDER BY avg_lead_time DESC;

/* 7g. US orders per factory */
SELECT Factory, COUNT(*) AS orders
FROM orders_routes
GROUP BY Factory
ORDER BY orders DESC;

/* ---- 8. Checks (expected values) ---- */
SELECT COUNT(*) AS orders_raw_rows FROM orders_raw;                 -- 10194
SELECT COUNT(*) AS orders_clean_rows FROM orders_clean;             -- 9881 (US 9687 + Canada 194)
SELECT COUNT(*) AS total_rows, COUNT(DISTINCT Route) AS routes,
       ROUND(AVG(Lead_Time_Adj * 1.0), 2) AS us_avg,
       SUM(CASE WHEN Lead_Time_Adj > 6 THEN 1 ELSE 0 END) AS delayed
FROM orders_routes;                                                 -- 9687, 177, 3.96, 613
SELECT status, COUNT(*) AS states FROM state_summary GROUP BY status;  -- Bottleneck 13, Normal 9, Low volume 27

SELECT * FROM orders_routes;
SELECT * FROM route_kpis;
SELECT * FROM state_summary;