/*
=====================================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
=====================================================================================
Script Purpose:  
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema. 
	Actions Performed:
    - Truncates 'silver' table.
    - Inserts transformed and cleaned data from 'bronze' into 'silver' table.

Parameters:
    None.
    This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL silver.load_silver();
=====================================================================================
*/

CREATE OR REPLACE PROCEDURE silver.load_silver()
LANGUAGE plpgsql
AS $$
DECLARE
	v_start_time TIMESTAMP;
	v_end_time TIMESTAMP;
	v_duration INTERVAL;
	v_table_start TIMESTAMP;
	v_err_msg TEXT;
	v_context TEXT;
BEGIN
	v_start_time := clock_timestamp();
	BEGIN
		RAISE NOTICE '==================================================';
		RAISE NOTICE 'Loading Silver Layer';
		RAISE NOTICE '==================================================';
	
		RAISE NOTICE '--------------------------------------------------';
		RAISE NOTICE 'Loading Income Table';
		RAISE NOTICE '--------------------------------------------------';
	
		RAISE NOTICE '>> Truncating Table: silver.income';
		TRUNCATE TABLE silver.income;

		v_table_start := clock_timestamp();
		RAISE NOTICE '>> Inserting Data Into: silver.income';
		INSERT INTO silver.income(
				SELECT
					job_name,
					start_date,
					end_date,
					date_string,
					start_date_if_equipment,
					num_days,
					job_position,
					rate,
					per_hours,
					notes,
					gross_1099,
					gross_w2,
					net_w2,
					tax_structure,
					payroll_name,
					between_date_1,
					between_date_2,
					between_date_3,
					between_date_4
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
						CASE
							WHEN end_date IS NULL
							THEN RIGHT(date_string, 10)::DATE
							ELSE end_date
						END AS end_date,
						date_string,
						start_date_if_equipment,
						CASE 
					        WHEN job_position ILIKE ANY (ARRAY['%equipment%', '%covid%'])
								OR job_name ILIKE '%kill%' THEN 0
							WHEN date_string LIKE '%;%' THEN
					        	REGEXP_COUNT(date_string, ';') + 1
							WHEN date_string LIKE '%-%' THEN
								SPLIT_PART(date_string, '-', 2)::DATE - 
								SPLIT_PART(date_string, '-', 1)::DATE + 1
					        ELSE num_days 
				    	END AS num_days,
						job_position,
						REPLACE(REPLACE(rate, '$', ''), ',', '')::NUMERIC::INT AS rate,
						per_hours,
						notes,
						REPLACE(REPLACE(gross_1099, '$', ''), ',', '')::NUMERIC AS gross_1099,
						REPLACE(REPLACE(gross_w2, '$', ''), ',', '')::NUMERIC AS gross_w2,
						REPLACE(REPLACE(net_w2, '$', ''), ',', '')::NUMERIC AS net_w2,
						CASE WHEN gross_1099 IS NOT NULL THEN '1099'
							WHEN gross_w2 IS NOT NULL THEN 'W2'
							ELSE tax_structure
						END AS tax_structure,
						CASE WHEN payroll_name IS NULL THEN 'n/a'
							ELSE payroll_name
						END AS payroll_name,
						between_date_1,
						between_date_2,
						between_date_3,
						between_date_4,
						ROW_NUMBER() OVER(
							PARTITION BY job_name, job_position, start_date
							ORDER BY start_date
						) AS row_num
					FROM bronze.income
				) t
				WHERE row_num = 1);
		RAISE NOTICE '>> Table silver.income >> Load Duration: % Seconds', EXTRACT (EPOCH FROM (clock_timestamp() - v_table_start));
		RAISE NOTICE '>> -------------------------';

		EXCEPTION WHEN OTHERS THEN
			GET STACKED DIAGNOSTICS
					v_err_msg = MESSAGE_TEXT,
					v_context = PG_EXCEPTION_CONTEXT;
				RAISE EXCEPTION '==================================================
	ERROR OCCURED DURING LOADING SILVER LAYER
	Error Message: %
	Context Info: %
	Error Code: %
	Load Failed After % Seconds
	==================================================',
		v_err_msg,
		v_context,
		SQLSTATE,
		EXTRACT(EPOCH FROM (clock_timestamp() - v_start_time));
    END;
	v_end_time := clock_timestamp();
	v_duration := v_end_time - v_start_time;
	RAISE NOTICE '==================================================';
	RAISE NOTICE 'Loading Silver Layer Is Completed';
	RAISE NOTICE '>> Full Load Duration: % Seconds', EXTRACT(EPOCH FROM v_duration);
	RAISE NOTICE '==================================================';

END;
$$;
