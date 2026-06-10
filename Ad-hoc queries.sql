/* Business Request - 1: City—Level Fare and Trip Summary Report

Generate a report that displays the total trips, average fare per km, average fare per trip, and the percentage contribution of each city’s
trips to the overall trips. This report will help in assessing trip volume, pricing efficiency, and each city’s contribution to the overall
trip count.

  Fields:

    city_name
    total_trips
    avg_fare_per_km
    avg_fare_per_trip
    %_contribution_to_total_trips */

WITH city_stats AS (
    SELECT
        c.city_name,
        COUNT(*) AS total_trips,
        SUM(t.distance_travelled_km) AS total_travelled_distance,
        SUM(t.fare_amount) AS total_revenue
    FROM dim_city c 
    JOIN fact_trips t 
        ON c.city_id = t.city_id
    GROUP BY c.city_name
)
SELECT 
    city_name,
    total_trips,
    ROUND(total_revenue / total_travelled_distance, 2) AS avg_fare_per_km,
    ROUND(total_revenue / total_trips, 2) AS avg_fare_per_trip,
    ROUND(total_trips*100 / (SELECT COUNT(*) FROM fact_trips), 2) AS contribution_to_total_trips
FROM city_stats;


/* Business Request - 2: Monthly City-Level Trips Target Performance Report

Generate a report that evaluates the target performance for trips at the monthly and city level. For each city and month, compare the actual
total trips with the target trips and categorise the performance as follows:

  If actual trips are greater than target trips, mark it as "Above Target".
  If actual trips are less than or equal to target trips, mark it as "Below Target".

Additionally, calculate the % difference between actual and target trips to quantify the performance gap.

  Fields:

    City_name
    month_name
    actua|_trips
    target_trips
    performance_status
    %_difference  */

WITH city_stats AS (
    SELECT
        MONTHNAME(t.date) AS month_name, 
        c.city_id,
        c.city_name,
        COUNT(*) AS total_trips
    FROM
        dim_city c
    JOIN
        fact_trips t ON c.city_id = t.city_id
    GROUP BY
        MONTHNAME(t.date),
        c.city_id,
        c.city_name
),
target_stats AS (
    SELECT
        MONTHNAME(target.month) AS month_name, 
        target.city_id,
        target.total_target_trips
    FROM
        targets_db.monthly_target_trips AS target
),
actual_vs_target AS (
    SELECT
        cts.city_name,
        cts.month_name, 
        cts.total_trips,
        ts.total_target_trips,
        (cts.total_trips - ts.total_target_trips) AS actual_difference_gap
    FROM
        city_stats cts
    JOIN
        target_stats ts
        ON cts.month_name = ts.month_name AND cts.city_id = ts.city_id 
)
SELECT
    city_name,
    month_name, 
    total_trips AS actual_trips,
    total_target_trips AS target_trips,
    actual_difference_gap,
    CASE
        WHEN total_trips > total_target_trips THEN 'Above_Target'
        ELSE 'Below_Target'
    END AS performance_status
FROM
    actual_vs_target
ORDER BY
    month_name; 



/* Business Request - 3: City-Level Repeat Passenger Trip Frequency Report

Generate a report that shows the percentage distribution of repeat passengers by the number of trips they have taken in each city.
Calculate the percentage of repeat passengers who took 2 trips, 3 trips, and so on, up to 10 trips.

Each column should represent a trip count category, displaying the percentage of repeat passengers who fall into that category out of the
total repeat passengers for that city.

This report will help identify cities with high repeat trip frequency, which can indicate strong customer loyalty or frequent usage patterns.

  Fields: city_name, 2-Trips, 3-Trips, 4-Trips, 5-Trips, 6-Trips, 7-Trips, 8-Trips, 9-Trips, 10-Trips  */

with trips as(
select 
	c.city_name,
    sum(rtp.repeat_passenger_count) as total_trips,
    sum(case when rtp.trip_count='2-Trips' then repeat_passenger_count end) as two_trips,
     sum(case when rtp.trip_count='3-Trips' then repeat_passenger_count end) as three_trips,
      sum(case when rtp.trip_count='4-Trips' then repeat_passenger_count end) as four_trips,
       sum(case when rtp.trip_count='5-Trips' then repeat_passenger_count end) as five_trips,
        sum(case when rtp.trip_count='6-Trips' then repeat_passenger_count end) as six_trips,
         sum(case when rtp.trip_count='7-Trips' then repeat_passenger_count end) as seven_trips,
          sum(case when rtp.trip_count='8-Trips' then repeat_passenger_count end) as eight_trips,
           sum(case when rtp.trip_count='9-Trips' then repeat_passenger_count end) as nine_trips,
            sum(case when rtp.trip_count='10-Trips' then repeat_passenger_count end) as ten_trips
	from dim_repeat_trip_distribution  rtp
	join dim_city c 
	on rtp.city_id=c.city_id
	group by c.city_name
)
select
	city_name,
	round(two_trips/total_trips*100,2) as Trip_2,
	round(three_trips/total_trips*100,2) as Trip_3,
	round(four_trips/total_trips*100,2) as Trip_4,
	round(five_trips/total_trips*100,2) as Trip_5,
	round(six_trips/total_trips*100,2) as Trip_6,
	round(seven_trips/total_trips*100,2) as Trip_7,
	round(eight_trips/total_trips*100,2) as Trip_8,
	round(nine_trips/total_trips*100,2) as Trip_9,
	round(ten_trips/total_trips*100,2) as Trip_10
from trips;



/* Business Request - 4: Identify Cities with Highest and Lowest Total New Passengers

Generate a report that calculates the total new passengers for each city and ranks them based on this value. Identify the top 3 cities with
the highest number of new passengers as well as the bottom 3 cities with the lowest number of new passengers, categorising them as "Top 3"
or "Bottom 3" accordingly.

  Fields

    city_name
    total_new_passengers
    city_category ("Top 3" or "Bottom 3")  */

select
	c.city_name,
	sum(s.total_passengers) as total_passengers,
	sum(s.new_passengers) as new_passengers,
	round(sum(s.new_passengers)/sum(s.total_passengers)*100,2) as new_passenger_pct
from
	fact_passenger_summary s 
join
	dim_city c on s.city_id=c.city_id
	group by
		c.city_name
	order by
		sum(s.new_passengers) asc
	limit 3;




/* Business Request - 5: Identify Month with Highest Revenue for Each City

Generate a report that identifies the month with the highest revenue for each city. For each city, display the month_name, the revenue amount
for that month, and the percentage contribution of that month’s revenue to the city’s total revenue.

  Fields

    city_name
    highest_revenue_month
    revenue
    percentage_contribution (%)  */

WITH monthly_revenue AS (
    -- Step 1: Calculate revenue per city, per month
    SELECT
        c.city_name,
        MONTHNAME(t.date) AS month_name,
        SUM(t.fare_amount) AS monthly_revenue
    FROM
        fact_trips t
    JOIN
        dim_city c ON t.city_id = c.city_id
    GROUP BY
        c.city_name,
        MONTHNAME(t.date) 
),
city_total_revenue AS (
    SELECT
        c.city_name,
        SUM(t.fare_amount) AS total_city_revenue
    FROM
        fact_trips t
    JOIN
        dim_city c ON t.city_id = c.city_id
    GROUP BY
        c.city_name 
),
revenue_ranking as(
SELECT
    mr.city_name,
    mr.month_name,
    mr.monthly_revenue AS revenue,
    ROUND(mr.monthly_revenue / ctr.total_city_revenue * 100, 2) AS revenue_share,
    dense_rank() over(partition by mr.city_name order by mr.monthly_revenue desc) as rnk
FROM
    monthly_revenue mr
JOIN
    city_total_revenue ctr ON mr.city_name = ctr.city_name
)
select 
city_name,
month_name,
revenue,
revenue_share
from revenue_ranking 
where rnk=1;


/* Business Request - 6: Repeat Passenger Rate Analysis

Generate a report that calculates two metrics:

  1. Monthly Repeat Passenger Rate: Calculate the repeat passenger rate for each city and month by com paring the number of repeat passengers
    to the total passengers.
  2. City-wide Repeat Passenger Rate: Calculate the overall repeat passenger rate for each city, considering all passengers across months.

These metrics will provide insights into monthly repeat trends as well as the overall repeat behaviour for each city.

  Fields:

    city_name
    month
    total_passengers
    repeat_passengers
    month|y_repeat_passenger_rate (%): Repeat passenger rate at the city and month level
    city_repeat_passenger_rate (%): Overall repeat passenger rate for each city, aggregated across months */

WITH monthly_stats AS (
    SELECT
        s.city_id,
        c.city_name,
        s.month,
        MONTHNAME(s.month) AS month_name,
        s.total_passengers,
        s.repeat_passengers,
        ROUND(s.repeat_passengers * 100.0 / s.total_passengers, 2) AS monthly_repeat_passenger_rate
    FROM
        fact_passenger_summary s
    JOIN
        dim_city c ON s.city_id = c.city_id
)
SELECT
    city_name,
    month_name AS month,
    total_passengers,
    repeat_passengers,
    monthly_repeat_passenger_rate,
    ROUND(
        SUM(repeat_passengers) OVER (PARTITION BY city_name) * 100.0 /
        SUM(total_passengers) OVER (PARTITION BY city_name),
    2) AS city_repeat_passenger_rate
FROM
    monthly_stats
ORDER BY
    city_name,
    month; 


-- for each city in each monthly target difference percentage
WITH trip_performance AS (
    SELECT
        c.city_name,
        d.month_name,
        ROUND(
            ((COUNT(t.trip_id) - mt.total_target_trips) * 100.0)
            / mt.total_target_trips,
            2
        ) AS pct_difference
    FROM trips_db.fact_trips t
    JOIN trips_db.dim_date d
        ON t.date = d.date
    JOIN targets_db.monthly_target_trips mt
        ON t.city_id = mt.city_id
       AND d.start_of_month = mt.month
    JOIN trips_db.dim_city c
        ON t.city_id = c.city_id
    GROUP BY
        c.city_name,
        d.month_name,
        mt.total_target_trips
)

SELECT
    month_name AS Month,

    MAX(CASE WHEN city_name = 'Chandigarh' THEN pct_difference END) AS Chandigarh,
    MAX(CASE WHEN city_name = 'Coimbatore' THEN pct_difference END) AS Coimbatore,
    MAX(CASE WHEN city_name = 'Indore' THEN pct_difference END) AS Indore,
    MAX(CASE WHEN city_name = 'Jaipur' THEN pct_difference END) AS Jaipur,
    MAX(CASE WHEN city_name = 'Kochi' THEN pct_difference END) AS Kochi,
    MAX(CASE WHEN city_name = 'Lucknow' THEN pct_difference END) AS Lucknow,
    MAX(CASE WHEN city_name = 'Mysore' THEN pct_difference END) AS Mysore,
    MAX(CASE WHEN city_name = 'Surat' THEN pct_difference END) AS Surat,
    MAX(CASE WHEN city_name = 'Vadodara' THEN pct_difference END) AS Vadodara,
    MAX(CASE WHEN city_name = 'Visakhapatnam' THEN pct_difference END) AS Visakhapatnam

FROM trip_performance
GROUP BY month_name
ORDER BY
    FIELD(month_name,
        'January','February','March','April','May','June');
