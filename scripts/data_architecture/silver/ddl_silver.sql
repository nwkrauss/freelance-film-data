/*
=====================================================================================
DDL Script: Create Silver Table
=====================================================================================
Script Purpose:  
    This script creates a table in the 'silver' schema, dropping an existing table if
    it already exists.
    Run this script to re-define the DDL of the 'silver' table.
=====================================================================================
*/

DROP TABLE IF EXISTS silver.income CASCADE;
CREATE TABLE silver.income (
	job_name VARCHAR(200),
	start_date DATE,
	end_date DATE,
	date_string VARCHAR(200),
	num_days INT,
	job_position VARCHAR(50),
	rate VARCHAR(50),
	per_hours INT,
	notes VARCHAR(200),
	gross_1099 INT,
	gross_w2 INT,
	net_w2 INT,
	tax_structure VARCHAR(10),
	payroll_name VARCHAR(999),
	between_date_1 DATE,
	between_date_2 DATE,
	between_date_3 DATE,
	between_date_4 DATE,
	job_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
