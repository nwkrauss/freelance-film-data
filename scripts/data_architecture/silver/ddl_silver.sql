/*
=====================================================================================
DDL Script: Create Silver Table
=====================================================================================
Script Purpose:  
    This script creates tables in the 'silver' schema, dropping existing tables if
    they already exist.
    Run this script to re-define the DDL of the 'bronze' tables.
=====================================================================================
*/

DROP TABLE IF EXISTS silver.income;
CREATE TABLE silver.income (
	job_name VARCHAR(500),
	start_date DATE,
	end_date DATE,
	date_string VARCHAR(200),
	start_date_if_equipment DATE,
	num_days INT,
	job_position VARCHAR(50),
	rate INT,
	per_hours INT,
	notes VARCHAR(200),
	gross_1099 NUMERIC,
	gross_w2 NUMERIC,
	net_w2 NUMERIC,
	tax_structure VARCHAR(10),
	payroll_name VARCHAR(200),
	between_date_1 DATE,
	between_date_2 DATE,
	between_date_3 DATE,
	between_date_4 DATE,
	job_key INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
