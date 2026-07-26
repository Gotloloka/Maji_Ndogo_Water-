USE MASTER;
GO
--Drop and create new "DataWarehouse" database

IF EXISTS ( SELECT 1 FROM sys.databases  WHERE name='Moversdata ')
BEGIN
	ALTER DATABASE Moversdata SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
	DROP DATABASE Moversdata;

END;
GO
-- Creating data warehouse database 
CREATE DATABASE Moversdata;
GO
USE Moversdata;
GO

-- Creating Schema 
CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
