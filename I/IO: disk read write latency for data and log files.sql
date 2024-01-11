/************************************************************************************************************************************************************************************************************************************
************************************************************************************************************************************************************************************************************************************
Author		: 	Subbu
 
Purpose		:	Gives you the disk latency for READ / WRITE operations on DATA and LOG files.
				if Data read/write > 20 ms and Log Read / write > 15 ms then its something to look out for.
				This script generates recommendations as well ..
				This is part of my project that I am working for SQL Server health checker ..... 
				
				Hopefully I can opensource it soon  and contribute to SQL Server community.....
				*** I am aware that this script uses "sp_MSforeachdb" - undocumented, but there is a more realiable sp_MSforeachdb written by Aaron Bertrand 
				(http://www.mssqltips.com/sqlservertip/2201/making-a-more-reliable-and-flexible-spmsforeachdb/) ***
				
 
Disclaimer
The views expressed on my posts on this site are mine alone and do not reflect the views of my company. All posts of mine are provided "AS IS" with no warranties, and confers no rights.
 
The following disclaimer applies to all code, scripts and demos available on my posts:
 
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED “AS IS” WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
 
I grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: 
 
(i) 	to use my name, logo, or trademarks to market Your software product in which the Sample Code is embedded; 
(ii) 	to include a valid copyright notice on Your software product in which the Sample Code is embedded; and 
(iii) 	to indemnify, hold harmless, and defend me from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
************************************************************************************************************************************************************************************************************************************
*************************************************************************************************************************************************************************************************************************************/
 


--- #### - Disk latency (Read and Write) on data and log files
IF OBJECT_ID('tempdb..#dbFiles') IS NOT NULL
	DROP TABLE #dbFiles;

IF OBJECT_ID('tempdb..#dbLatency') IS NOT NULL
	DROP TABLE #dbLatency;

CREATE TABLE #dbFiles (
	DBName SYSNAME
	,NAME VARCHAR(200)
	,physical_name VARCHAR(2000)
	,type_desc VARCHAR(200)
	,state_desc VARCHAR(200)
	,FILE_ID INT
	);

EXEC sp_MSforeachdb 'use [?]
      insert into #dbFiles
      select ''?'' as [DBName],name , physical_name,type_desc, state_desc,file_id
      from sys.database_files'

DECLARE @DataReadLatency_ms INT
	,@DataWriteLatency_ms INT
DECLARE @LogReadLatency_ms INT
	,@LogWriteLatency_ms INT

---- CHANGE HERE if you want to have your latencies defined less or more
---- Below are the standard practice .. if Data read/write > 20 ms and Log Read / write > 15 ms then its something to look out for.
SET @DataReadLatency_ms = 20
SET @DataWriteLatency_ms = 20
SET @LogReadLatency_ms = 15
SET @LogWriteLatency_ms = 15

SELECT DB_NAME(database_id) AS 'DatabaseName'
	,io_stall_read_ms / NULLIF(num_of_reads, 0) AS 'AVG READ Time (Transfer/msec)'
	,io_stall_write_ms / NULLIF(num_of_writes, 0) AS 'AVG WRITE Time (Transfer/msec)'
	,cast(size_on_disk_bytes / 1024.0 / 1024.0 AS DECIMAL(15, 2)) AS 'Size_on_disk_MB'
	,df.NAME AS 'LogicalFileName'
	,df.physical_name AS 'PhysicalFileName'
	,CASE 
		WHEN df.type_desc = 'ROWS'
			THEN 'Data'
		ELSE 'Log'
		END AS 'type_desc'
INTO #dbLatency
FROM sys.dm_io_virtual_file_stats(- 1, - 1) stat
JOIN #dbFiles df ON stat.file_id = df.FILE_ID
	AND df.DBName = DB_NAME(stat.database_id)
WHERE num_of_reads > 0
	AND num_of_writes > 0
	AND (
		(
			ISNULL((io_stall_read_ms / NULLIF(num_of_reads, 0)), 0) > @DataReadLatency_ms
			AND type_desc = 'ROWS'
			OR ISNULL((io_stall_write_ms / NULLIF(num_of_writes, 0)), 0) > @DataWriteLatency_ms
			AND type_desc = 'ROWS'
			)
		OR (
			ISNULL((io_stall_read_ms / NULLIF(num_of_reads, 0)), 0) > @LogReadLatency_ms
			AND type_desc = 'LOG'
			OR ISNULL((io_stall_write_ms / NULLIF(num_of_writes, 0)), 0) > @LogWriteLatency_ms
			AND type_desc = 'LOG'
			)
		)

if exists (select 1 from #dbLatency)
begin
SELECT 'HIGH' AS SEVERITY
	,'SQL Server Database Health' AS GROUP_TYPE
	,'[' + stuff((
			SELECT '[' + 'Database ' + [DatabaseName] 
				+ CASE 
					WHEN [AVG READ Time (Transfer/msec)] >= 20
						AND [AVG WRITE Time (Transfer/msec)] < 20
						AND [type_desc] = 'Data'
						THEN ' is having High AVG READ Time = ' + cast([AVG READ Time (Transfer/msec)] AS VARCHAR(4)) + 'msec from Data file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk.'
					WHEN [AVG WRITE Time (Transfer/msec)] >= 20
						AND [AVG READ Time (Transfer/msec)] < 20
						AND [type_desc] = 'Data'
						THEN ' is having High AVG WRITE Time = ' + cast([AVG WRITE Time (Transfer/msec)] AS VARCHAR(4)) + ' msec to Data file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk.'
					WHEN [AVG READ Time (Transfer/msec)] >= 20
						AND [AVG WRITE Time (Transfer/msec)] >= 20
						AND [type_desc] = 'Data'
						THEN ' is having High AVG READ Time = ' + cast([AVG READ Time (Transfer/msec)] AS VARCHAR(4)) + 'msec ' + ' and also having High AVG WRITE Time = ' + cast([AVG WRITE Time (Transfer/msec)] AS VARCHAR(4)) + 'msec from Data file' + '. Which means Both Reads and Writes are taking longer from/to Data file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk.'
					WHEN [AVG READ Time (Transfer/msec)] >= 15
						AND [AVG WRITE Time (Transfer/msec)] < 15
						AND [type_desc] = 'Log'
						THEN ' is having High AVG READ Time = ' + cast([AVG READ Time (Transfer/msec)] AS VARCHAR(4)) + 'msec from Log file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk.'
					WHEN [AVG WRITE Time (Transfer/msec)] >= 15
						AND [AVG READ Time (Transfer/msec)] < 15
						AND [type_desc] = 'Log'
						THEN ' is having High AVG WRITE Time = ' + cast([AVG WRITE Time (Transfer/msec)] AS VARCHAR(4)) + ' msec to Log file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk.'
					WHEN [AVG READ Time (Transfer/msec)] >= 15
						AND [AVG WRITE Time (Transfer/msec)] >= 15
						AND [type_desc] = 'Log'
						THEN ' is having High AVG READ Time = ' + cast([AVG READ Time (Transfer/msec)] AS VARCHAR(4)) + 'msec ' + ' and also having High AVG WRITE Time = ' + cast([AVG WRITE Time (Transfer/msec)] AS VARCHAR(4)) + 'msec from Log file' + '. Which means Both Reads and Writes are taking longer from/to Log file' + ' .The phyiscal file is ' + [PhysicalFileName] + ' which is ' + cast([Size_on_disk_MB] AS VARCHAR(max)) + 'MB in Size on disk'
					ELSE 'IO Subsystem is good !!'
					END + ']; '
			FROM #dbLatency
			FOR XML path('')
			), 1, 1, '') AS COMMENTS
	,'Disk Perfmon counters can be used to identify I/O Bottleneck - Disk Bytes /sec, Process:IO Data Bytes/Sec, Buffer Manager: Page Read/sec + Page Writes/sec, Disk sec/Transfer ; Collect data from sys.dm_io_virtual_file_stats and sys.dm_io_pending_io_requests; Ask your storage admins to monitor the entire IO subsystem from the Windows system all the way through to the underlying disks.
	Ref: http://blogs.msdn.com/b/karthick_pk/archive/2012/06/26/io_2d00_bottlenecks.aspx, http://blogs.msdn.com/b/sqlsakthi/archive/2011/02/09/troubleshooting-sql-server-i-o-requests-taking-longer-than-15-seconds-i-o-stalls-amp-disk-latency.aspx' AS RECOMMENDATIONS
	end
	else 
	select 'The Disks are performing good !'
