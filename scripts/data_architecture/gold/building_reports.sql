/*============================================================
This is a work in progress as I build reports.
============================================================
*/

-- 1.)
-- Creating Gold View of Cumulative Year Facts
WITH position_summaries AS (
    -- Calculate income per position per year
    SELECT
        EXTRACT(YEAR FROM start_date) AS year,
        job_position,
        SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS pos_income
    FROM silver.income
    GROUP BY 1, 2
),
ranked_positions AS (
	SELECT
		year,
		job_position,
		DENSE_RANK() OVER (PARTITION BY year ORDER BY pos_income DESC) AS rank_desc
	FROM position_summaries
),
top_earning_positions AS (
    -- Identify the position with the MAX income for each year
    SELECT
        year,
		MAX(CASE WHEN rank_desc = 1 THEN job_position END) AS top_position,
        MAX(CASE WHEN rank_desc = 2 THEN job_position END) AS second_position,
		MAX(CASE WHEN rank_desc = 3 THEN job_position END) AS third_position
    FROM ranked_positions
	WHERE rank_desc <= 3
	GROUP BY year
),
yearly_totals AS (
	-- Calculate sums of gross income and days worked
    SELECT
        EXTRACT(YEAR FROM start_date) AS year,
        SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS gross_income,
        SUM(num_days) AS total_days_worked
    FROM silver.income
    WHERE EXTRACT(YEAR FROM start_date) <> 2021
    GROUP BY 1
),
aggregate_income AS (
	-- Aggregate sums for averages and lag
    SELECT 
        y.year,
        y.gross_income,
        t.top_position, -- Added here
		t.second_position,
		t.third_position,
        LAG(y.gross_income) OVER (ORDER BY y.year) AS prev_year_income,
        ROUND(AVG(CASE WHEN y.year <> 2026 THEN y.gross_income END) OVER ()::numeric, 2) AS avg_yearly_income,
        y.total_days_worked,
        ROUND(AVG(y.total_days_worked) OVER ()) AS avg_days_worked
    FROM yearly_totals y
    LEFT JOIN top_earning_positions t ON y.year = t.year -- Joined here
),
yearly_difference AS (
	-- Using the lag, calculate percent change
	SELECT
		year,
		gross_income,
		avg_yearly_income,
		ROUND(
			((gross_income - prev_year_income) / NULLIF(prev_year_income, 0)) * 100,
			2
		) AS percent_change,
		total_days_worked,
		top_position,
		second_position,
		third_position
	FROM aggregate_income
)
SELECT
	-- Final display
    year,
    gross_income,
	percent_change,
	total_days_worked,
    avg_yearly_income,
	ROUND(AVG(CASE WHEN YEAR <> 2026 THEN percent_change END) OVER(), 2) AS avg_percent_change,
	ROUND(gross_income / total_days_worked, 2) AS avg_daily_rate,
	top_position,
	second_position,
	third_position
FROM yearly_difference
ORDER BY year;

-- 2.)
-- Creating a Gold View for Month Facts 
WITH position_summaries AS (
	-- Calculate income per position per month
    SELECT
       	DATE_TRUNC('month', start_date) AS month_date,
		EXTRACT(YEAR FROM start_date) AS year,
        job_position,
        SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS pos_income
    FROM silver.income
    GROUP BY 1, 2, 3
),
ranked_positions AS (
	-- Add ranking for job positions by each position's income
	SELECT
		month_date,
		job_position,
		DENSE_RANK() OVER (PARTITION BY month_date ORDER BY pos_income DESC) AS rank_desc
	FROM position_summaries
),
top_earning_positions AS (
	-- Identify the position with the MAX income for each month
    SELECT
        month_date,
		MAX(CASE WHEN rank_desc = 1 THEN job_position END) AS top_position
    FROM ranked_positions
	WHERE rank_desc <= 1
	GROUP BY month_date
),
monthly_totals AS (
	-- Calculate sums for gross income and days worked
    SELECT
       	DATE_TRUNC('month', start_date) AS month_date,		
        SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS gross_income,
        SUM(num_days) AS total_days_worked
    FROM silver.income
    WHERE EXTRACT(YEAR FROM start_date) <> 2021
    GROUP BY 1
),
aggregate_income AS (
	-- Aggregate sums for averages and lag
	-- Join the monthly totals table with ranked job positions table
    SELECT 
        m.month_date,
        m.gross_income,
        t.top_position, -- Added here
        LAG(m.gross_income) OVER (ORDER BY m.month_date) AS prev_month_income,
        ROUND(
			AVG(m.gross_income) OVER (
				PARTITION BY EXTRACT(MONTH FROM m.month_date)
			)::numeric, 2
		) AS avg_monthly_income,
		ROUND(AVG(m.gross_income) OVER ()::numeric, 2) AS avg_month_global,
        m.total_days_worked,
        ROUND(AVG(m.total_days_worked) OVER ()) AS avg_days_worked
    FROM monthly_totals m
    LEFT JOIN top_earning_positions t ON m.month_date = t.month_date -- Joined here
),
monthly_difference AS (
	-- Using the lag, calculate percent change
	SELECT
		month_date,
		EXTRACT(YEAR FROM month_date) AS year,
		gross_income,
		avg_monthly_income,
		avg_month_global,
		ROUND(
			((gross_income - prev_month_income) / NULLIF(prev_month_income, 0)) * 100,
			2
		) AS percent_change,
		total_days_worked,
		top_position
	FROM aggregate_income
)
SELECT
	-- Final display
	EXTRACT(MONTH from month_date) AS month,
	year,
    gross_income,
	percent_change,
	total_days_worked,
    avg_monthly_income,
	avg_month_global,
	ROUND(gross_income / total_days_worked, 2) AS avg_daily_rate,
	top_position
FROM monthly_difference
ORDER BY year, month;

-- Create a Gold View for Job Position Facts across years

-- Create a Gold View for CURRENT YEAR (2026) where I can track monthly & yearly income against average monthly & yearly income

-- Other ideas:
-- >> What is the percentage that I might work on any given day of the week? 
