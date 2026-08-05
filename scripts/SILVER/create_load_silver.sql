/* 
==================================================================
Stored Procedure: Load Silver Layer (Source ->Silver)
==================================================================
Script Purpose: 
	This stored procedure performs the ETL (Extract,Transform, Load) process to populate the 'Silver' scheam tables from the 'Bronze' schema
	It performs the following actions:
	- Create and Load tables
	- Table are standardised by filter Null value and and repeated the data 

Parameters:
	None.
 This stored procedure does not accept any parameters or return any values.

Usage Example:
	EXEC silver.load_silver 
==================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN 
DECLARE @start_time DATETIME, @end_Time DATETIME;
DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
BEGIN TRY

	SET @start_time = GETDATE();
	PRINT'>> Drop Table: silver.multi_shift ';
	DROP TABLE IF EXISTS silver.multi_shift  ;
	PRINT '>> Create and Inserting Data Into: gold.multi_shift ';
	SELECT * INTO silver.multi_shift FROM  (
	SELECT
		CONCAT( s.asset_caption,'_', DATEPART(MONTH, s.shift_date),'_',s.day_of_month) AS multi_shift_key,
		s.asset_caption ASasset_description,
		REPLACE(TRIM(REPLACE(s.shift_caption,'-','')),' ','_') AS work_shift,
		s.asset_class,
		CAST(s.shift_date AS DATE) shift_day,
		CAST(s.shift_date as TIME(0)) AS shift_start,
		CAST(s.first_ignition_on AS TIME(0)) AS first_ignition_on ,
		CAST(s.last_ignition_off AS TIME(0)) AS last_ignition_off,
		CAST(s.first_cycle_start_timestamp AS TIME(0)) AS start_cycle ,
		CAST(s.last_cycle_start_timestamp AS TIME(0)) AS last_cycle,
		CAST(s.tonnage_total as FLOAT) AS tonnage,
		ROUND(CAST(s.bcm_total AS FLOAT),2) as bcm_total,
		CAST(s.cycle_count AS FLOAT) AS cycle_count,
		DATEDIFF(second, s.shift_date, s.first_cycle_start_timestamp) as before_cycle,
		DATEDIFF(second, s.first_cycle_start_timestamp, s.last_cycle_start_timestamp) as operational_time,
		s.known_operation_delay_seconds,
		s.Unknown_operation_dealy_seconds,
		s.other_travel_seconds,
		ROUND(CAST(s.maintenance_hours as FLOAT)*3600,2 ) as maintenance_seconds ,
		ROUND(s.planned_maintenance_hours*3600, 2) AS planned_mantenance_seconds,
		CAST(s.availability_ as FLOAT) availiblty_seconds,
		CAST(s.utilization_seconds AS FLOAT) AS utilization_seconds 
	FROM bronze.multi_shift s
	WHERE s.cycle_count  is not null and s.asset_caption like 'Bell%') t;
	SET @end_time = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();
	PRINT'>> Drop Table: silver.operational_delays_haul';
	DROP TABLE IF EXISTS silver.operational_delays_haul;
	PRINT '>> Create and Inserting Data Into: silver.operational_delays_hau';
	SELECT * INTO silver.operational_delays_haul FROM (
	SELECT DISTINCT
				CONCAT(so.AssetDescription,'_',DATEPART(month, so.ReportEventStartTimestamp),'_',  DATEPART(DAY,so.ReportEventStartTimestamp)) as operational_key,
				so.assetdescription,
				so.assetclass,
				so.originalEventType AS orginal_event_type,
				TRIM(REPLACE(so.work_shift,'Mine Area ','')) AS work_shift,
				so.geofenceName,
				CAST( so.ReportEventStartTimestamp as DATE) AS report_start_dt,
				CAST(so.ReportEventEndTimestamp as DATE) report_end_date,
				so.category,
				so.description_haul,
				so.reason,
				so.MineAreaCaption,
				SUM(CAST(so.DurationSeconds AS FLOAT)) OVER (PARTITION BY CONCAT(so.AssetDescription,'_',DATEPART(month, so.ReportEventStartTimestamp),'_',  DATEPART(DAY,so.ReportEventStartTimestamp)),so.originalEventType, work_shift, geofencename, description_haul) as total_duration
			FROM bronze.operational_delays_haul so) t;
	SET @end_time = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();
	PRINT'>> Drop Table: silver.maintenance';
	DROP TABLE IF EXISTS silver.maintenance ;
	PRINT '>> Create and Inserting Data Into: silver.maintenance';
	SELECT * INTO silver.maintenance FROM(
	SELECT DISTINCT
		t.maintenance_key,
		t.asset_description,
		t.maintenance_area,
		t.maintenance_reason,
		t.Category,
		t.asset_id,
		t.Remarks,
		t.IsPlanned,
		t.job_start_dt,
		t.shift_reported,
		t.job_complete_dt,
		t.shift_complete,
		ROUND(SUM(t.Duration_in_hours*3600) OVER ( PARTITION BY maintenance_key,shift_reported, shift_complete ),2) as total_seconds_spent

	FROM (
		SELECT
				CONCAT(ma.assetDescription,'_',DATEPART(MONTH, ma.JobStartTimestamp),'_',DATEPART(DAY,ma.JobStartTimestamp)) as maintenance_key,
				ma.assetDescription as asset_description,
				ma.MaintenanceAreaName as maintenance_area,
				ma.MaintenanceReason as maintenance_reason,
				ma.Remarks,
				ma.Category,
				ma.AssetId as asset_id,
				CAST(ma.JobStartTimestamp AS DATE) as job_start_dt,
				CASE WHEN DATEPART(hour,ma.JobStartTimestamp  ) between 6.5 and 18.5 THEN 'Day Shift'
				ELSE 'Night shift'
				end shift_reported,
				CAST(ma.JobCompletedTimestamp AS DATE) AS job_complete_dt,
				CASE WHEN DATEPART(hour,ma.JobCompletedTimestamp ) between 6.30 and 18.30 THEN 'Day Shift'
				ELSE 'Night shift'
				end shift_complete,
				ma.IsPlanned,
				ma.Duration_in_hours
			FROM bronze.maintenance ma 
			where ma.IsPlanned = 'FALSE' ) t)t;
	SET @end_time = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();
	PRINT'>> Drop Table: silver.cycle_review ';
	DROP TABLE IF EXISTS silver.cycle_review ;
	PRINT '>> Create and Inserting Data Into: silver.cycle_review ';
	SELECT * INTO silver.cycle_review FROM(
	SELECT
			 CONCAT(c.truck,'_',DATEPART(MONTH,c.start_timestamp ),'_',DATEPART(DAY,c.start_timestamp)) AS cycle_review_key,
			 c.truck AS asset_description,
			 CAST(c.start_timestamp AS DATE ) AS shift_date,
			 CAST(c.start_timestamp AS TIME(0)) AS start_time,
			 CASE WHEN DATEPART(HOUR, c.start_timestamp) between 6.30 and 18.30 THEN 'Morning shift'
			 ELSE 'Night shift'
			 END shift_work,
			 c.loading_area,
			 c.dumping_area,
			 CAST(c.loading_timestamp AS TIME(0)) AS loading_timestamp,
			 CASt(c.dumping_timestamp AS TIME(0)) as dumping_timestamp,
			 CAST(REPLACE(c.travel_distance_laden_metres,'-','') as FLOAT) AS travel_distance_laden,
			 CAST(REPLACE(c.travel_distance_unladen_metres,'-','') as FLoat) AS travel_distance_unladen,
			 CAST(REPLACE(c.average_speed_laden_km_h,'-','') AS FLOAt) AS average_speed_laden ,
			 CAST(REPLACE(c.average_speed_unladen_km_h,'-','') AS FLOAT) AS average_speed_unladen,
			 CAST(REPLACE(c.travel_seconds_laden,'-','') as FLOAT) as travel_laden,
			 CAST(REPLACE(c.travel_seconds_unladen,'-','') as FLOAt) as travel_unladen,
			 CAST(REPLACE(c.fill_time,'-','') AS FLOAT) AS filling_time,
			 CAST(REPLACE(c.queue_time,'-','') AS FLOAt) AS queueing_time,
			 CAST(REPLACE(c.cycle_time,'-','')  AS FLOAT) AS cycle_delays,
			 CAST(REPLACE(c.dumping_time,'-','') AS FLOAT) AS dumping_time,
			 CAST(REPLACE(c.loading_time,'-','') AS FLOAT) AS loading_time,
				 CAST(REPLACE(c.travel_seconds_unladen,'-','') as FLOAt) +
				 CAST(REPLACE(c.travel_seconds_laden,'-','') as FLOAT) +
				 CAST(REPLACE(c.cycle_time,'-','')  AS FLOAT) +
				 CAST(REPLACE(c.dumping_time,'-','') AS FLOAT) +
				 CAST(REPLACE(c.loading_time,'-','') AS FLOAT) as cycle_time_seconds
		FROM bronze.cycle_review c) t;

	SET @batch_end_time = GETDATE();
	PRINT '===============================================================================';
		PRINT 'Loading Silver Layer is Completed';
		PRINT '	- Total Load Duration: ' + CAST( DATEDIFF(SECOND,@batch_start_time,@batch_end_time) as NVARCHAR)+'seconds';
	PRINT '===============================================================================';	
END TRY
BEGIN CATCH
	PRINT '==============================================================================='
			PRINT 'ERROR OCCURED DURING LOADING of SILVER LAYER'
			PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
			PRINT 'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
			PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);

	PRINT '==============================================================================='
END CATCH
END ;
