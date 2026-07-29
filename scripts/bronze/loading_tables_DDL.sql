CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
DECLARE @batch_start_time DATETIME,@batch_end_time DATETIME;	
DECLARE @start_time DATETIME, @end_time DATETIME ;

BEGIN TRY 
	SET @batch_start_time = GETDATE();
	PRINT '===============================================================';
	PRINT 'LOADING BRONZE LAYER';
	PRINT '===============================================================';

	SET @start_time = GETDATE(); --   assign the current date and time
	PRINT '---------------------------------------------------------------';
	PRINT 'Loading Movers DATA Tables';
	PRINT '---------------------------------------------------------------';
	PRINT 'Truncating the table  cycle_review';
	TRUNCATE TABLE bronze.cycle_review --- clean the table before loading the data ;
	PRINT '>> Inserting Data Into: Bronze.cycle_review'
	BULK INSERT bronze.cycle_review 
	FROM 'C:\Users\user\Downloads\movers\Cycle Review December 2025.csv'
	with( first_row = 2, fieldterminator = ',', rowterminator = '\n', tablock);
	SET @END_TIME = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '--------------------';

	SET @start_time = GETDATE(); --   assign the current date and time
	PRINT 'Truncating the table  bronze.operational_delays_haul';
	TRUNCATE TABLE bronze.operational_delays_haul-- clean the table before loading the data ;
	PRINT '>> Inserting Data Into: bronze.operational_delays_haul'
	BULK INSERT bronze.operational_delays_haul
	FROM 'C:\Users\user\Downloads\movers\Operational Delays Haul  1.12.2025 - 10.12.2025.csv'
	with( first_row = 2, fieldterminator = ',', rowterminator = '\n', tablock);
	SET @END_TIME = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '--------------------';

	SET @start_time = GETDATE(); --   assign the current date and time
	PRINT 'Truncating the table  bronze.multi_shift';
	TRUNCATE TABLE bronze.multi_shift-- clean the table before loading the data ;
	PRINT '>> Inserting Data Into: bronze.multi_shift'
	BULK INSERT bronze.multi_shift
	FROM 'C:\Users\user\Downloads\movers\Multi Shift AR 22_1_2026 @ 12_59_0 December 2025.csv'
	with( first_row = 2, fieldterminator = ',', rowterminator = '\n', tablock);
	SET @END_TIME = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '--------------------';

	SET @start_time = GETDATE(); --   assign the current date and time
	PRINT 'Truncating the table  bronze.maintenance';
	TRUNCATE TABLE bronze.maintenance-- clean the table before loading the data ;
	PRINT '>> Inserting Data Into: bronze.maintenance'
	BULK INSERT bronze.maintenance
	FROM 'C:\Users\user\Downloads\movers\Maintenance AR 22_1_2026 December 2025.csv'
	with( first_row = 2, fieldterminator = ',', rowterminator = '\n', tablock);
	SET @END_TIME = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '--------------------';
	SET @batch_end_time = GETDATE();
	PRINT '===============================================================================';
	PRINT 'Loading Bronze Layer is Completed';
		PRINT '	- Total Load Duration: ' + CAST( DATEDIFF(SECOND,@batch_start_time,@batch_end_time) as NVARCHAR)+'seconds';
		PRINT '===============================================================================';
END TRY
BEGIN CATCH
		PRINT '==============================================================================='
		PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER'
		PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
		PRINT 'ERROR NUMBER' + CAST(ERROR_NUMBER() AS NVARCHAR);
		PRINT 'ERROR STATE' + CAST(ERROR_STATE() AS NVARCHAR);
		PRINT '==============================================================================='		
END CATCH
END ;
