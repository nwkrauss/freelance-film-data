/*
=====================================================================================
DDL Script: Create Gold Views
=====================================================================================
Script Purpose:  
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables.

    Each view performs transformations and combines data from the Silver layer to 
    produce a clean, enriched, and business-ready dataset.

Usage:
    These views can be queried directly for analytics and reporting.
=====================================================================================
*/

-- =====================================================================================
-- Create Fact Table: gold.job_facts
-- =====================================================================================
DROP VIEW IF EXISTS gold.job_facts;
CREATE OR REPLACE VIEW gold.job_facts AS
	SELECT
		start_date,
		job_name,
		job_position,
		CASE
			WHEN rate IS NOT NULL THEN rate::text
			ELSE 'n/a' END AS rate,
		CASE
			WHEN per_hours IS NOT NULL THEN per_hours::text
			ELSE 'n/a' END AS per_hours,
		num_days,
		CASE
			WHEN gross_1099 IS NULL THEN 0
			ELSE gross_1099 END AS gross_1099,
		CASE
			WHEN gross_w2 IS NULL THEN 0
			ELSE gross_w2 END AS gross_w2,
		CASE
			WHEN net_w2 IS NULL THEN 0
			ELSE net_w2 END AS net_w2,
		tax_structure,
		payroll_name,
		CASE
			WHEN notes IS NULL THEN 'n/a'
			ELSE notes END AS notes,
		between_date_1,
		between_date_2,
		between_date_3,
		between_date_4,
		end_date
	FROM silver.income;

-- =====================================================================================
-- Create Fact Table: gold.yearly_report
-- =====================================================================================
DROP VIEW IF EXISTS gold.yearly_report;
-- THIS QUERY IS FOR CURRENT YEAR REPORT
-- TO CAPTURE HISTORICAL DATA, REMOVE '<> 2026' FILTERS
CREATE OR REPLACE VIEW gold.yearly_report AS
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
	        ROUND(AVG(CASE WHEN y.year <> 2026 THEN y.total_days_worked END) OVER ()) AS avg_days_worked
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
				((gross_income::NUMERIC - prev_year_income) / NULLIF(prev_year_income, 0)) * 100,
				2
			) AS income_pc_from_previous,
			total_days_worked,
			avg_days_worked,
			top_position,
			second_position,
			third_position
		FROM aggregate_income
	)
	SELECT
		-- Final display
	    year,
	    gross_income,
		income_pc_from_previous,
		total_days_worked,
		CASE
			WHEN gross_income > avg_yearly_income THEN 'Above'
			WHEN gross_income < avg_yearly_income THEN 'Below'
			ELSE 'Equal'
		END AS compare_to_avg,
	    avg_yearly_income,
		ROUND(AVG(CASE WHEN YEAR <> 2026 THEN income_pc_from_previous END) OVER(), 2) AS avg_pc_yearly_income,
		ROUND(gross_income / total_days_worked, 2) AS avg_daily_rate,
		avg_days_worked,
		top_position,
		second_position,
		third_position
	FROM yearly_difference
	ORDER BY year;

-- =====================================================================================
-- Create Fact Table: gold.monthly_report
-- =====================================================================================
DROP VIEW IF EXISTS gold.monthly_report;

CREATE OR REPLACE VIEW gold.monthly_report AS
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
			MAX(CASE WHEN rank_desc = 1 THEN job_position END) AS top_position,
			MAX(CASE WHEN rank_desc = 2 THEN job_position END) AS second_position
	    FROM ranked_positions
		WHERE rank_desc <= 2
		GROUP BY month_date
	),
	monthly_totals AS (
		-- Calculate sums for gross income and days worked
	    SELECT
	       	DATE_TRUNC('month', start_date) AS month_date,		
	        SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS total_income,
	        SUM(num_days) AS days_worked_this_month
	    FROM silver.income
	    WHERE EXTRACT(YEAR FROM start_date) <> 2021
	    GROUP BY 1
	),
	aggregate_income AS (
		-- Aggregate sums for averages and lag
		-- Join the monthly totals table with ranked job positions table
	    SELECT 
	        m.month_date,
	        m.total_income,
	        t.top_position,
			t.second_position,
	        LAG(m.total_income) OVER (ORDER BY m.month_date) AS prev_month_income,
	        ROUND(
				AVG(m.total_income) OVER (
					PARTITION BY EXTRACT(MONTH FROM m.month_date)
				)::numeric, 2
			) AS avg_income_of_month,
			ROUND(AVG(m.total_income) OVER ()::numeric, 2) AS avg_month_global,
	        m.days_worked_this_month,
	        ROUND(AVG(m.days_worked_this_month) OVER ()) AS avg_days_worked
	    FROM monthly_totals m
	    LEFT JOIN top_earning_positions t ON m.month_date = t.month_date -- Joined here
	),
	monthly_difference AS (
		-- Percent Change: Calculate using the lag 
		SELECT
			month_date,
			EXTRACT(YEAR FROM month_date) AS year,
			total_income,
			avg_income_of_month,
			avg_month_global,
			ROUND(
				((total_income - prev_month_income)::NUMERIC / NULLIF(prev_month_income, 0)) * 100,
				2
			) AS income_pc_from_previous,
			days_worked_this_month,
			top_position,
			second_position
		FROM aggregate_income
	)
	SELECT
		-- Final display
		CONCAT (TO_CHAR(month_date, 'Mon'), ' ', year) AS month_key,
		EXTRACT(MONTH from month_date) AS month,
		year,
	    total_income::NUMERIC,
		income_pc_from_previous,
		days_worked_this_month,
		CASE
			WHEN total_income > avg_income_of_month THEN 'Above'
			WHEN total_income < avg_income_of_month THEN 'Below'
			ELSE 'Equal'
		END AS compare_to_avg,
	    avg_income_of_month,
		avg_month_global,
		ROUND(total_income / days_worked_this_month, 2) AS avg_daily_rate_this_month,
		top_position,
		second_position
	FROM monthly_difference
	ORDER BY year, month;

-- =====================================================================================
-- Create Fact Table: gold.position_report
-- =====================================================================================
DROP VIEW IF EXISTS gold.position_report;
CREATE OR REPLACE VIEW gold.position_report AS
	SELECT
	    job_position,
		COALESCE(SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) 
	        FILTER (WHERE EXTRACT(YEAR FROM start_date) = 2026), 0) AS income_2026,
		COALESCE(SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) 
	        FILTER (WHERE EXTRACT(YEAR FROM start_date) = 2025), 0) AS income_2025,
		COALESCE(SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) 
	        FILTER (WHERE EXTRACT(YEAR FROM start_date) = 2024), 0) AS income_2024,
		COALESCE(SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) 
	        FILTER (WHERE EXTRACT(YEAR FROM start_date) = 2023), 0) AS income_2023,
		COALESCE(SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) 
	        FILTER (WHERE EXTRACT(YEAR FROM start_date) = 2022), 0) AS income_2022,
		SUM(COALESCE(gross_1099, 0) + COALESCE(gross_w2, 0)) AS total_all_years
	FROM silver.income
	GROUP BY 1
	ORDER BY total_all_years DESC;
