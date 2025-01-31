-- BUSINESS REQUEST : City Level  Fare & Trip Summary Report
SELECT
	c.city_name,
    COUNT(f.trip_id) as total_trips,
    ROUND(avg(f.fare_amount / NULLIF(f.distance_travelled_km, 0)),2) as avg_fare_per_km,
    ROUND(avg(f.fare_amount), 2) as avg_fare_per_trip,
    CONCAT(
	ROUND(
		(count(f.trip_id)*100 / sum(count(f.trip_id)) over()),
		2
	), '%'
 ) As contribution_of_total_trips
from
  fact_trips f
join 
dim_city c on f.city_id = c.city_id
group by 
c.city_name
order by
 total_trips;
 
 
 -----------------------------------------------------------------------------------------------------------------------------------
 -- BUSINESS REQUEST : Monthly City Level Trip Target Performance Report  
SELECT 
	c.city_name,
    d.month_name,
    COUNT(f.trip_id) AS actual_trip,
    t.total_target_trips AS target_trip,
    CASE
		WHEN 
			COUNT(f.trip_id) > t.total_target_trips THEN 'Above Target'
		ELSE 
			'Below Target'
	END Performance_status,
    CONCAT(
    ROUND(
		((COUNT(f.trip_id) - t.total_target_trips) * 100 / t.total_target_trips) , 
        2), '%') AS pct_differnce
from 
	fact_trips f
JOIN 
	dim_city c ON f.city_id = c.city_id 
JOIN 
	dim_date d on f.date = d.date
JOIN 
	targets_db.monthly_target_trips t on t.city_id = c.city_id
									  AND t.month = d.start_of_month
GROUP BY 
	c.city_name,
	d.month_name,
	t.total_target_trips,
	d.start_of_month
ORDER BY
	c.city_name,
	MONTH(d.start_of_month);

    
    -------------------------------------------------------------------------------------------------------------------------------
    -- BUSINESS REQUEST : City Level Repeat Passenger Trip Frequency Report
SELECT 
	c.city_name,
    ROUND((SUM(CASE WHEN r.trip_count = '2-Trips' THEN r.repeat_passenger_count ELSE 0 END) * 100.0) / SUM(r.repeat_passenger_count), 2) AS "2_Trips",
	ROUND((SUM(CASE WHEN r.trip_count = '3-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "3_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '4-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "4_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '5-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "5_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '6-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "6_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '7-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "7_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '8-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "8_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '9-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "9_Trips",
    ROUND((SUM(CASE WHEN r.trip_count = '10-Trips' THEN r.repeat_passenger_count ELSE 0 END) *100) / SUM(r.repeat_passenger_count), 2) AS "10_Trips"
FROM 
	dim_repeat_trip_distribution r
JOIN 
	dim_city c ON r.city_id = c.city_id
GROUP BY
	c.city_name
ORDER BY
	c.city_name;
    
    
    ---------------------------------------------------------------------------------------------------------------------
    -- BUSINESS REQUEST : Identityfy Cities with highest and lowest total new passenger
    
CREATE VIEW low3 AS 
	SELECT 
		c.city_name,
        sum(f.new_passengers) AS total_new_passenger
	FROM 
		fact_passenger_summary f
	JOIN 
		dim_city c ON c.city_id  = f.city_id
	GROUP BY 
		c.city_name
	ORDER BY 
		total_new_passenger ASC
	LIMIT 3 ;
CREATE VIEW highest3 AS 
	SELECT 
		c.city_name,
        sum(f.new_passengers) AS total_new_passenger
	FROM 
		fact_passenger_summary f
	JOIN 
		dim_city c ON c.city_id  = f.city_id
	GROUP BY 
		c.city_name
	ORDER BY 
		total_new_passenger DESC
	LIMIT 3;
    
SELECT 
	*, ('highest3') as category from highest3
UNION 
SELECT
	*, ('low3') as category from low3;
    
    
    
    -------------------------------------------------------------------------------------------------------------------
-- BUSINESS REQUEST : Idedntify month with highest revenue for  each city

CREATE VIEW city_profi AS
SELECT
	f.city_id,f.date,
	c.city_name,
    sum(f.fare_amount) as revenue
    
FROM 
	fact_trips f
JOIN 
	dim_city c ON c.city_id = f.city_id
GROUP BY  
	c.city_name,
	f.date,
    f.city_id;

CREATE VIEW city_profi_detail AS
SELECT*,
	MAX(revenue) OVER(partition by city_id) as max_rev,
	SUM(revenue) OVER(partition by city_id) as total_city_rev
FROM 
	city_profi;
    
CREATE VIEW city_highest_profi_month AS
SELECT
	distinct city_name, 
    max_rev,
    date_format(date, '%M') as highest_revenue_month,
    total_city_rev,
    ROUND( (max_rev / total_city_rev) *100, 2) as revenue_contribution
FROM 
	city_profi_detail
WHERE
	revenue = max_rev;
    
SELECT
	city_name,
    highest_revenue_month,
    max_rev AS revenue,
    revenue_contribution as pct_contribution
FROM 
	city_highest_profi_month;
    
    
    --------------------------------------------------------------------------------------------------------------
-- BUSINESS REQUEST - repeat passenger rate analysis
    
with MonthlyRate AS (
	SELECT 
		c.city_name,
		p.month,
		p.total_passengers,
		p.repeat_passengers,
		ROUND((p.repeat_passengers / p.total_passengers) * 100.0 ,2) AS monthly_repeat_passenger_rate
	FROM
		dim_city c
	JOIN	
		fact_passenger_summary p ON c.city_id = p.city_id
),
 
 CitywideRate AS(
	SELECT
		c.city_name,
        SUM(p.total_passengers) as total_passengers,
        SUM(p.repeat_passengers) as repeat_passengers,
		ROUND((SUM(p.repeat_passengers)/ SUM(p.total_passengers)) * 100, 2) AS city_repeat_passenger_rate
	FROM 
		dim_city c
	JOIN 
		fact_passenger_summary p ON c.city_id = p.city_id
	GROUP BY 
		c.city_name)
        
	SELECT
		m.city_name,
        m.total_passengers,
        m.repeat_passengers,
        m.monthly_repeat_passenger_rate,
        c.city_repeat_passenger_rate
	FROM 
		MonthlyRate m
	JOIN
		CitywideRate c on c.city_name = m.city_name;
        
        

