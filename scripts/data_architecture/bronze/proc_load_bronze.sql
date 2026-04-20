/*
=====================================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
=====================================================================================
Script Purpose:  
	This stored procedure loads data into the 'bronze' schema from external CSV files.
	It performs the following actions:
	- Truncates the bronze tables before loading data.
	- Uses the COPY command to load data from CSV files to bronze tables.

Parameters:
	None.
	This stored procedure does not accept any parameters or return any values.

Usage Example:
	CALL bronze.load_bronze();
=====================================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
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
		RAISE NOTICE 'Loading Bronze Layer';
		RAISE NOTICE '==================================================';
	
		RAISE NOTICE '--------------------------------------------------';
		RAISE NOTICE 'Loading Income Table';
		RAISE NOTICE '--------------------------------------------------';
	
		RAISE NOTICE '>> Truncating Table: bronze.income';
		TRUNCATE TABLE bronze.income;

		v_table_start := clock_timestamp();
		RAISE NOTICE '>> Inserting Data Into: bronze.income';
		COPY bronze.income(
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
				between_date_4)
		FROM '/Users/saxifrage/Desktop/Business/Data Analytics/Trustyfriend Income Data/CSV from Google Sheets/Trustyfriend_Income Data.csv'
		WITH (FORMAT CSV, HEADER true, DELIMITER ',');
		RAISE NOTICE '>> Table bronze.income >> Load Duration: % Seconds', EXTRACT (EPOCH FROM (clock_timestamp() - v_table_start));
		RAISE NOTICE '>> -------------------------';
	
		EXCEPTION
			WHEN OTHERS THEN
				GET STACKED DIAGNOSTICS
					v_err_msg = MESSAGE_TEXT,
					v_context = PG_EXCEPTION_CONTEXT;
				RAISE EXCEPTION '==================================================
	ERROR OCCURED DURING LOADING BRONZE LAYER
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
	RAISE NOTICE 'Loading Bronze Layer Is Completed';
	RAISE NOTICE '>> Full Load Duration: % Seconds', EXTRACT(EPOCH FROM v_duration);
	RAISE NOTICE '==================================================';
END;
$$;
