/* 
	Gold Layer
	- Create and Load tables
	- Table are standardised by filter Null value and and repeated the data 
*/
CREATE PROCEDURE gold.load_gold AS
BEGIN 
DECLARE @start_time DATETIME, @end_Time DATETIME;
DECLARE @batch_start_time DATETIME, @batch_end_time DATETIME;
BEGIN TRY

	SET @start_time = GETDATE();
	PRINT'>> Drop Table: gold.multi_shift ';
	DROP TABLE IF EXISTS gold.multi_shift  ;
	PRINT '>> Create and Inserting Data Into: gold.multi_shift ';
	SELECT * INTO gold.multi_shift FROM  (
	SELECT
		CONCAT( s.asset_caption,'_', DATEPART(MONTH, s.shift_date),'_',s.day_of_month) AS multi_shift_key,

		s.shift_caption,
		s.asset_class,
		CAST(s.shift_date AS DATE) shift_day,
		CAST(s.shift_date as TIME(0)) as shift_start,
		CAST(s.first_ignition_on AS TIME(0)) AS first_ignition_on ,
		CAST(s.last_ignition_off AS TIME(0)) AS last_ignition_off,
		CAST(s.first_cycle_start_timestamp AS TIME(0)) AS start_cycle ,
		CAST(s.last_cycle_start_timestamp AS TIME(0)) AS last_cycle,
		s.tonnage_total,
		round(s.bcm_total,2) as bcm_total,
		s.cycle_count,
		datediff(second, s.shift_date, s.first_cycle_start_timestamp) as before_cycle,
		datediff(second, s.first_cycle_start_timestamp, s.last_cycle_start_timestamp) as operational,
		s.known_operation_delay_seconds,
		s.Unknown_operation_dealy_seconds,
		s.other_travel_seconds,
		round(s.maintenance_hours*3600,2 ) as maintenance_seconds ,
		ROUND(s.planned_maintenance_hours*3600, 2) AS planned_mantenance_seconds,
		s.availability_,
		s.utilization_seconds	
	FROM silver.multi_shift s) t;
	SET @end_time = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();
	PRINT'>> Drop Table: gold.operational_delays_hau';
	DROP TABLE IF EXISTS gold.operational_delays_hau;
	PRINT '>> Create and Inserting Data Into: gold.operational_delays_hau';
	SELECT * INTO gold.operational_delays_haul FROM (
	SELECT DISTINCT
			t.operational_key,
			t.AssetDescription,
			t.AssetClass,
			t.orginal_event_type,
			t.work_shift,
			t.GeofenceName,
			t.report_start_dt,
			t.report_end_date,
			t.category,
			t.reason,
			t.MineAreaCaption,
			t.description_haul,
			sum(t.duration_seconds) OVER (PARTITION BY t.operational_key,t.orginal_event_type, t.work_shift, t.geofencename,t.description_haul) as total_duration
		FROM(
			SELECT
				CONCAT(so.AssetDescription,'_',DATEPART(month, so.ReportEventStartTimestamp),'_',  DATEPART(DAY,so.ReportEventStartTimestamp)) as operational_key,
				so.assetdescription,
				so.assetclass,
				so.originalEventType AS orginal_event_type,
				so.work_shift,
				so.geofenceName,
				cast( so.ReportEventStartTimestamp as DATE) AS report_start_dt,
				cast(so.ReportEventEndTimestamp as DATE) report_end_date,
				so.category,
				so.description_haul,
				so.reason,
				so.MineAreaCaption,
				so.DurationSeconds as duration_seconds
			FROM silver.operational_delays_haul so) t) t;
	SET @end_time = GETDATE();
	PRINT '>>Load Duration: '+ CAST(DATEDIFF(SECOND, @start_time,@end_time) as NVARCHAR) + 'seconds';
	PRINT '------------------------------------------------------------------------------------';
	SET @start_time = GETDATE();
	PRINT'>> Drop Table: gold.maintenance';
	DROP TABLE IF EXISTS gold.maintenanance ;
	PRINT '>> Create and Inserting Data Into: gold.maintenance';
	SELECT * INTO gold.maintenance FROM(
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
		ROUND(SUM(t.Duration_in_hours*3600) OVER ( PARTITION BY maintenance_key,shift_reported, shift_complete ORDER BY  job_start_dt),2) as total_seconds_spent

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
	PRINT'>> Drop Table: gold.cycle_review ';
	DROP TABLE IF EXISTS gold.cycle_review ;
	PRINT '>> Create and Inserting Data Into: gold.cycle_review ';
	SELECT * INTO gold.cycle_review FROM(
	SELECT
		 concat(c.truck,'_',datepart(month,c.start_timestamp ),'_',datepart(day,c.start_timestamp)) as cycle_review_key,
		 c.truck AS asset_description,
		 CAST(c.start_timestamp AS DATE ) AS Shift_date,
		 CAST(c.start_timestamp AS TIME(0)) AS start_time,
		 CASE WHEN DATEPART(HOUR, c.start_timestamp) between 6.30 and 18.30 THEN 'Morning shift'
		 ELSE 'Night shift'
		 END shift_work,
		 c.loading_area,
		 c.dumping_area,
		 CAST(c.loading_timestamp AS TIME(0)) AS loading_timestamp,
		 CASt(c.dumping_timestamp AS TIME(0)) as dumping_timestamp,
		 c.travel_distance_laden_metres,
		 c.travel_distance_unladen_metres,
		 c.average_speed_laden_km_h,
		 c.average_speed_unladen_km_h,
		 c.fill_time,
		 c.queue_time,
		 c.cycle_time,
		 c.dumping_time,
		 c.loading_time,
		 c.cycle_time_seconds
	FROM silver.cycle_review c) t;

	SET @batch_end_time = GETDATE();
	PRINT '===============================================================================';
		PRINT 'Loading GOLD Layer is Completed';
		PRINT '	- Total Load Duration: ' + CAST( DATEDIFF(SECOND,@batch_start_time,@batch_end_time) as NVARCHAR)+'seconds';
	PRINT '===============================================================================';	
END TRY
BEGIN CATCH
	PRINT '==============================================================================='
			PRINT 'ERROR OCCURED DURING LOADINGnGOLD LAYER'
			PRINT 'ERROR MESSAGE' + ERROR_MESSAGE();
			PRINT 'ERROR MESSAGE' + CAST(ERROR_NUMBER() AS NVARCHAR);
			PRINT 'ERROR MESSAGE' + CAST(ERROR_STATE() AS NVARCHAR);

	PRINT '==============================================================================='
END CATCH
END ;
