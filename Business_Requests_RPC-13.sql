
-- BUSINESS REQUEST:1-City-Level Fare and Trip Summary Report

with CTE1 as
(Select city_name, count(trip_id) as Total_trips, 
round(sum(fare_amount)/sum(distance_travelled_km),2) as Avg_Fare_per_Km,
round(Avg(fare_amount),2) as Avg_Fare_per_trip 
 from fact_trips
 join dim_city on fact_trips.city_id=dim_city.city_id
 group by city_name) 
 select city_name, Total_trips, Avg_Fare_per_Km, Avg_Fare_per_trip, 
 concat(Cast((Total_trips)/sum(sum(Total_trips)) over (order by (Select Null))*100 as decimal(6,2)),'%') As Contribution_PCt
from CTE1
 group by city_name;


-- BUSINESS REQUEST:2-Monthly City-Level Trips Target Performance Report

WITH CTE1 AS (
    SELECT f.city_id, d.city_name, MONTH(f.date) AS Trip_month_num,
        MONTHNAME(f.date) AS Trip_month,
        f.trip_id 
    FROM 
        fact_trips f
    JOIN 
        dim_city d ON f.city_id = d.city_id
)
SELECT CTE1.city_name,  CTE1.Trip_month, COUNT(CTE1.trip_id) AS Actual_trips, 
    ta.total_target_trips AS Target_trips,
    CASE 
        WHEN COUNT(CTE1.trip_id) >= ta.total_target_trips THEN 'Above Target'
        ELSE 'Below Target'
    END AS Performance_Status,
    CONCAT(ROUND(((COUNT(CTE1.trip_id) - ta.total_target_trips) / ta.total_target_trips) * 100, 2),'%') AS Percentage_Difference
FROM 
    CTE1
JOIN 
    targets_db.monthly_target_trips ta 
    ON CTE1.city_id = ta.city_id 
    AND CTE1.Trip_month = MONTHNAME(ta.month)
GROUP BY  CTE1.city_name, CTE1.Trip_month, ta.total_target_trips, ta.city_id, CTE1.Trip_month_num
ORDER BY CTE1.city_name, CTE1.Trip_month_num;


-- BUSINESS REQUEST:3- City-Level Repeat Passenger Trip Frequency Report

WITH CTE1 AS (select
city_id, trip_count, sum(repeat_passenger_count) as Total_RP
from  dim_repeat_trip_distribution
group by city_id, trip_count),
CTE2 AS(
select city_id, trip_count, Total_RP, sum(Total_RP) over (partition by city_id) as City_total_RP,
concat(Cast((Total_RP/sum(Total_RP) over (partition by city_id))*100 as decimal(6,2)),'%') As Contribution_Pct
from CTE1
group by city_id, trip_count)
SELECT 
   city_name,
    MAX(CASE WHEN trip_count = '2-trips' THEN Contribution_Pct ELSE 0 END) AS '2-trips',
    MAX(CASE WHEN trip_count = '3-trips' THEN Contribution_Pct ELSE 0 END) AS '3-trips',
    MAX(CASE WHEN trip_count = '4-trips' THEN Contribution_Pct  ELSE 0 END) AS '4-trips',
    MAX(CASE WHEN trip_count = '5-trips' THEN Contribution_Pct  ELSE 0 END) AS '5-trips',
    MAX(CASE WHEN trip_count = '6-trips' THEN Contribution_Pct ELSE 0  END) AS '6-trips',
    MAX(CASE WHEN trip_count = '7-trips' THEN Contribution_Pct ELSE 0  END) AS '7-trips',
    MAX(CASE WHEN trip_count = '8-trips' THEN Contribution_Pct ELSE 0  END) AS' 8-trips',
    MAX(CASE WHEN trip_count = '9-trips' THEN Contribution_Pct ELSE 0  END) AS '9-trips',
    MAX(CASE WHEN trip_count = '10-trips' THEN Contribution_Pct  ELSE 0 END) AS '10-trips'
FROM 
    CTE2
    join dim_city on CTE2.city_id=dim_city.city_id
GROUP BY 
   city_name;
   
   
   -- BUSINESS REQUEST:4 Identify Cities with Highest and Lowerst Total_New_Passenger 

WITH CTE1 AS(
SELECT city_id, sum(new_passengers) as Total_New_Passengers
FROM fact_passenger_summary
GROUP BY city_id),
CTE2 AS(
SELECT city_name, Total_New_Passengers,
RANK () OVER(order by Total_New_Passengers DESC) as Ranking
FROM CTE1
 join dim_city on CTE1.city_id=dim_city.city_id),
CTE3 AS( 
 select city_name, Total_New_Passengers, 
 (CASE 
 WHEN Ranking <=3 THEN 'Top 3'
 WHEN Ranking >=8 THEN 'Bottom 3'
 ELSE 'Middle Rank'
 END) AS City_Category
 FROM CTE2
GROUP BY city_name, Total_New_Passengers)
SELECT city_name,Total_New_Passengers, City_Category FROM CTE3
WHERE city_Category='Top 3' OR City_Category='Bottom 3';


-- BUSINESS REQUEST:5 Identify Month with Highest Revenue for Each City

WITH CTE1 AS (select monthname(date) as Month, city_id, sum(fare_amount) as Total_Rev FROM fact_trips
group by city_id, Month),
CTE2 AS(
select city_id, Month, Total_Rev, max(Total_Rev) OVER(partition by city_id) as Highest_Rev FROM CTE1
group by city_id, Month),
CTE3 AS(
SELECT city_name, Month, Highest_rev, Total_Rev,
CONCAT(ROUND((Highest_Rev/sum(Total_Rev) over (Partition by CTE2.city_id))*100,2),'%') AS Contribution_perct
FROM CTE2
JOIN dim_city on CTE2.city_id=dim_city.city_id)
SELECT City_name, Month as Highest_Revenue_Month, Highest_rev as Revenue, Contribution_perct
FROM CTE3
WHERE Highest_rev=Total_rev;


--  BUSINESS REQUEST:6A  Repeat Passenger Rate Analysis
--  Monthly Repeat Passenger Rate 

SELECT 
    city_name,
    MONTHNAME(month) AS Month,
    total_passengers,
    repeat_passengers,
    CONCAT(ROUND((repeat_passengers / total_passengers) * 100,
                    2),
            '%') AS Monthly_Repeat_Passenger_Rate
FROM
    fact_passenger_summary
        JOIN
    dim_city ON fact_passenger_summary.city_id = dim_city.city_id;
 
 
 --  BUSINESS REQUEST:6B  Repeat Passenger Rate Analysis
--  City-Wide Repeat Passenger Rate 

SELECT 
    city_name,
    CONCAT(ROUND(SUM(repeat_passengers) / SUM(total_passengers) * 100,
                    2),
            '%') AS Overall_Repeat_passenger_Rate
FROM
    fact_passenger_summary f
        JOIN
    dim_city d ON f.city_id = d.city_id
GROUP BY f.city_id
ORDER BY Overall_Repeat_passenger_Rate DESC;






