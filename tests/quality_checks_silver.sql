/*
=====================================================================================
Quality Checks
=====================================================================================
Script Purpose:  
    This script performs various quality checks for data consistency, accuracy, and 
    standardization across the 'silver' schemas. It includes checks for:
    - Null or duplicate job entries.
    - Unwanted spaces in string fields.
    - Data standardization and consitency.
    - Invaild date ranges and orders.
    - Data consistency between related fields.

Usage Notes:
    - Run these checks after data loading the 'silver' layer.
    - Investigate and resolve any discrepencies found during the checks.
=====================================================================================
*/

-- Verify start_date is populated
-- >> Expectation: No Result
SELECT
	job_name,
	start_date
FROM (
	SELECT
		job_name,
		CASE
			WHEN UPPER(job_position) LIKE '%EQUIPMENT%'
			OR UPPER(job_position) LIKE '%COVID%'
			OR UPPER(job_name) LIKE '%KILL%'
			THEN LEFT(date_string, 10)::DATE
			ELSE start_date
		END AS start_date,
		date_string,
		job_position
	FROM bronze.income)
WHERE start_date IS NULL;

