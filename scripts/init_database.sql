/*
============================================================
Create Database and Schemas
============================================================
Script Purpose:  
    This script creates a new database named 'Trustyfriend'.
    Additionally, the script sets up three schemas within the database:
    'bronze', 'silver', and 'gold'.  

WARNING:
    Running this script will create a new database 'Trustyfriend'.
    If 'Trustyfriend' already exists, all data in the database
    might be permanently deleted. Proceed with caution and ensure
    you have proper backups before running this.
*/

CREATE DATABASE Trustyfriend;

CREATE SCHEMA bronze;
CREATE SCHEMA silver;
CREATE SCHEMA gold;
