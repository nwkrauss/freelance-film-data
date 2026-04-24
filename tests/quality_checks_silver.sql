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

-- 1.) Checks for duplicate job_name entries
-- >> Expectation: No Results
SELECT
	job_name,
	job_position,
	start_date,
	COUNT(*) AS occurrence
FROM silver.income
GROUP BY job_name, job_position, start_date
HAVING COUNT(*) > 1;

-- 2.) Verifies start_date and end_date are populated
-- >> Expectation: No Results
SELECT
	job_name,
	start_date,
	end_date
FROM silver.income
WHERE start_date IS NULL
	OR end_date IS NULL;

-- 3.) Check for expected values in job_position
-- >> Expectation: No Results
SELECT job_position
FROM silver.income
WHERE job_position NOT IN (
	'Gaffer',
	'DP',
	'Grip',
	'Teacher',
	'BBE',
	'Covid Stipend',
	'Electric',
	'BBG',
	'Equipment Rental',
	'Graphic Design',
	'Photographer',
	'Cam Op',
	'G&E Swing',
	'Key Grip'
);

