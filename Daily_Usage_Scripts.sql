--#Script#: Running Process

SELECT  session_id ,DB_NAME(database_id) AS [Database], 
start_time ,
status ,
command,
wait_type,wait_time,blocking_session_id,open_transaction_count,cpu_time,total_elapsed_time,reads,writes,
request_id ,
percent_complete ,
estimated_completion_time ,
DATEADD(ms,estimated_completion_time,GETDATE()) AS EstimatedEndTime
FROM sys.dm_exec_requests
where session_id > 50
AND DB_NAME(database_id)=’DB_Name’

--#Script#: File Group Usage:
SELECT 
    [TYPE] = A.TYPE_DESC
    ,[FILE_Name] = A.name
    ,[FILEGROUP_NAME] = fg.name
    ,[File_Location] = A.PHYSICAL_NAME
    ,[FILESIZE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0)
    ,[USEDSPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - ((SIZE/128.0) - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT)/128.0))
    ,[FREESPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT)/128.0)
    ,[FREESPACE_%] = CONVERT(DECIMAL(10,2),((A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, 'SPACEUSED') AS INT)/128.0)/(A.SIZE/128.0))*100)
    ,[AutoGrow] = 'By ' + CASE is_percent_growth WHEN 0 THEN CAST(growth/128 AS VARCHAR(10)) + ' MB -' 
        WHEN 1 THEN CAST(growth AS VARCHAR(10)) + '% -' ELSE '' END 
        + CASE max_size WHEN 0 THEN 'DISABLED' WHEN -1 THEN ' Unrestricted' 
            ELSE ' Restricted to ' + CAST(max_size/(128*1024) AS VARCHAR(10)) + ' GB' END 
        + CASE is_percent_growth WHEN 1 THEN ' [autogrowth by percent, BAD setting!]' ELSE '' END
FROM sys.database_files A LEFT JOIN sys.filegroups fg ON A.data_space_id = fg.data_space_id 
order by A.TYPE desc, A.NAME; 

--#Scripts#: Disk Capacity on windows level.
SELECT
    @@SERVERNAME Server,
    Volume,
    CAST(SizeGB as DECIMAL(10,2)) CapacityGB,
    CAST((SizeGB - FreeGB) as DECIMAL(10,2)) UsedGB,
    CAST(FreeGB as DECIMAL(10,2)) FreeGB,
    CAST([%Free] as DECIMAL(10,2))[%Free]
    FROM(
        SELECT distinct(volume_mount_point) Volume, 
          (total_bytes/1048576)/1024.00 as SizeGB, 
          (available_bytes/1048576)/1024.00 as FreeGB,
          (select ((available_bytes/1048576* 1.0)/(total_bytes/1048576* 1.0) *100)) as '%Free'
        FROM sys.master_files AS f CROSS APPLY 
          sys.dm_os_volume_stats(f.database_id, f.file_id)
        group by volume_mount_point, total_bytes/1048576, 
          available_bytes/1048576  )T

--TSQL Script to get Backup & Restore % completion & estimated time complete
SELECT command,
            s.text,
            percent_complete, 
            CAST(((DATEDIFF(s,start_time,GetDate()))/3600) as varchar) + ' hour(s), '
                  + CAST((DATEDIFF(s,start_time,GetDate())%3600)/60 as varchar) + 'min, '
                  + CAST((DATEDIFF(s,start_time,GetDate())%60) as varchar) + ' sec' as running_time,
            CAST((estimated_completion_time/3600000) as varchar) + ' hour(s), '
                  + CAST((estimated_completion_time %3600000)/60000 as varchar) + 'min, '
                  + CAST((estimated_completion_time %60000)/1000 as varchar) + ' sec' as est_time_to_go,
            dateadd(second,estimated_completion_time/1000, getdate()) as est_completion_time 
FROM sys.dm_exec_requests r
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) s
WHERE r.command in ('RESTORE DATABASE', 'BACKUP DATABASE', 'RESTORE LOG', 'BACKUP LOG')

--#Scripts#: File group size increase
USE master;  
GO

ALTER DATABASE TEMPDB   
MODIFY FILE  
(
  NAME = templog,  
  SIZE = 13119
  );  
GO

--#Scripts#: SQL Server Service Information
SELECT servicename,process_id,startup_type_desc,status_desc,
last_startup_time,service_account,is_clustered,cluster_nodename,filename
FROM sys.dm_server_services with (NOLOCK)

--#Scripts#: GET information about your Cluster Node and there Status.
SELECT NodeName,status_description,is_current_owner
FROM sys.dm_os_cluster_nodes WITH (NOLOCK) OPTION (RECOMPILE)

#the database is in single-user mode, and a user is currently connected to it.
SELECT request_session_id FROM sys.dm_tran_locks WHERE resource_database_id = DB_ID(‘XYZ’)

use master
kill 55 -- the connection to the database in single user mode

alter database XYZ set multi_user with rollback immediate

--#Scripts#: Log File Full
DBCC SQLPERF(LOGSPACE) 
select log_reuse_wait_desc,Name from sys.databases where name ='TEMPDB'  
 
--#Scripts: Job Name
select * from msdb.dbo.sysjobs where job_id=0x940DD56AC2A3F04BBD3EDA097F9AB919

--#Scripts: SQL Server Current memory usage
select
      physical_memory_in_use_kb/1048576.0 AS 'physical_memory_in_use (GB)',
      locked_page_allocations_kb/1048576.0 AS 'locked_page_allocations (GB)',
      virtual_address_space_committed_kb/1048576.0 AS 'virtual_address_space_committed (GB)',
      available_commit_limit_kb/1048576.0 AS 'available_commit_limit (GB)',
      page_fault_count as 'page_fault_count'
from  sys.dm_os_process_memory;

--#Scripts#: Performance Counters:
SELECT object_name, counter_name, cntr_value FROM sys.dm_os_performance_counters 
where (object_name like '%Buffer Manager%' and counter_name like '%page life%')
or (object_name like '%Memory Manager%' and counter_name like '%memory grants pending%')
or (object_name like '%Memory Manager%' and counter_name like '%target server memory%')
or (object_name like '%Memory Manager%' and counter_name like '%total server memory%')
or (object_name like '%Buffer Manager%' and counter_name like '%Buffer cache hit ratio%')
or (object_name like '%Buffer Manager%' and counter_name IN ('Page reads/sec', 'Page writes/sec', 'Lazy writes/sec', 'Memory Grants Outstanding'))

--#Scripts#: Easy Index suggestion
DECLARE @DBID INT
 SELECT @DBID = DB_ID()
 SELECT OBJECT_NAME([OBJECT_ID]) 'TABLE NAME',INDEX_TYPE_DESC 'INDEX TYPE',IND.[NAME],CASE WHEN AVG_FRAGMENTATION_IN_PERCENT <30 THEN 'To Be Re-Organized' ELSE 'To Be Rebuilt' END 'ACTION TO BE TAKEN' ,AVG_FRAGMENTATION_IN_PERCENT '% FRAGMENTED'
FROM sys.dm_db_index_physical_stats(@DBID, NULL, NULL, NULL, NULL) JOIN sys.sysindexes IND
 ON (IND.ID =[OBJECT_ID] AND IND.INDID = INDEX_ID)
 WHERE AVG_FRAGMENTATION_IN_PERCENT > 0
 AND DATABASE_ID = @DBID
 AND IND.FIRST IS NOT NULL
 AND IND.[NAME] IS NOT NULL
 ORDER BY 5 DESC

--#Scripts#: Display all sleeping process:
SELECT 
 spid,
 a.status,
 hostname,  
 program_name,
 cmd,
 cpu,
  physical_io,
  blocked,
  b.name,
  loginame
FROM   
  master.dbo.sysprocesses  a INNER JOIN
  master.dbo.sysdatabases b  ON
    a.dbid = b.dbid where a.status like '%sleeping%' and spid> 50
ORDER BY spid 

--#Scripts#: Failover AG:
;WITH cte_HADR AS (SELECT object_name, CONVERT(XML, event_data) AS data
FROM sys.fn_xe_file_target_read_file('AlwaysOn*.xel', null, null, null)
WHERE object_name = 'error_reported'
)

SELECT data.value('(/event/@timestamp)[1]','datetime') AS [timestamp],
       data.value('(/event/data[@name=''error_number''])[1]','int') AS [error_number],
       data.value('(/event/data[@name=''message''])[1]','varchar(max)') AS [message]
FROM cte_HADR
order by timestamp desc

--#Scripts#: Querying All Actively Running Agent Jobs in SQL Server
SELECT  j.name AS 'Job Name',
	j.job_id AS 'Job ID',
    j.originating_server AS 'Server',
    a.run_requested_date AS 'Execution Date',
    DATEDIFF(SECOND, a.run_requested_date, GETDATE()) AS 'Elapsed(sec)',
    CASE WHEN a.last_executed_step_id is null
		THEN 'Step 1 executing'
		ELSE 'Step ' + CONVERT(VARCHAR(25), last_executed_step_id + 1)
                  + ' executing'
        END AS 'Progress'
FROM msdb.dbo.sysjobs_view j
	INNER JOIN msdb.dbo.sysjobactivity a ON j.job_id = a.job_id
    INNER JOIN msdb.dbo.syssessions s ON s.session_id = a.session_id
    INNER JOIN (SELECT MAX(agent_start_date) AS max_agent_start_date
          FROM msdb.dbo.syssessions) s2 ON s.agent_start_date = s2.max_agent_start_date
WHERE stop_execution_date IS NULL
AND run_requested_date IS NOT NULL


--#Scripts#: Identifying the Longest Running Queries in Your Database
SELECT TOP 10 PERCENT 
    o.name AS 'Object Name',
	qs.total_elapsed_time / qs.execution_count / 1000.0 AS 'Average Seconds',
    qs.total_elapsed_time / 1000.0 AS 'Total Seconds',
    total_physical_reads AS'Physical Reads',
    total_logical_reads AS 'Logical Reads',
	qs.execution_count AS 'Count',
    SUBSTRING (qt.text,qs.statement_start_offset/2, 
         (CASE WHEN qs.statement_end_offset = -1 
            THEN LEN(CONVERT(NVARCHAR(MAX), qt.text)) * 2 
          ELSE qs.statement_end_offset END - qs.statement_start_offset)/2) AS 'Query',
	DB_NAME(qt.dbid) AS 'Database',
	last_execution_time AS 'Last Executed',
	@@ServerName AS 'Server Name'
  FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) as qt
    LEFT OUTER JOIN sys.objects o ON qt.objectid = o.object_id
where qt.dbid = DB_ID()
  ORDER BY 'Average Seconds' DESC;

--#Scripts#: Currently long running transactions:
SELECT
	r.session_id
,	r.start_time
,	TotalElapsedTime_ms = r.total_elapsed_time
,	r.[status]
,	r.command
,	DatabaseName = DB_Name(r.database_id)
,	r.wait_type
,	r.last_wait_type
,	r.wait_resource
,	r.cpu_time
,	r.reads
,	r.writes
,	r.logical_reads
,	t.[text] AS [executing batch]
,	SUBSTRING(
				t.[text], r.statement_start_offset / 2, 
				(	CASE WHEN r.statement_end_offset = -1 THEN DATALENGTH (t.[text]) 
						 ELSE r.statement_end_offset 
					END - r.statement_start_offset ) / 2 
			 ) AS [executing statement] 
,	p.query_plan
FROM
	sys.dm_exec_requests r
CROSS APPLY
	sys.dm_exec_sql_text(r.sql_handle) AS t
CROSS APPLY	
	sys.dm_exec_query_plan(r.plan_handle) AS p
ORDER BY 
	r.total_elapsed_time DESC;


--#Scripts#: Procedure Stats (Queries)
SET STATISTICS TIME ON
SET STATISTICS IO ON

select DEST.text,
SUBSTRING(DEST.text, (DEQS.statement_start_offset/2)+1,
((CASE DEQS.statement_end_offset
WHEN -1 THEN DATALENGTH(DEST.text)
ELSE DEQS.statement_end_offset
END - DEQS.statement_start_offset)/2) + 1) as statement_text,
DEQS.*
from sys.dm_exec_query_stats as DEQS
cross apply sys.dm_exec_sql_text (DEQS.sql_handle) DEST


--#Scripts#: VLF’s Count for all databases.
SELECT [name], s.database_id,
COUNT(l.database_id) AS 'VLF Count',
SUM(vlf_size_mb) AS 'VLF Size (MB)',
SUM(CAST(vlf_active AS INT)) AS 'Active VLF',
SUM(vlf_active*vlf_size_mb) AS 'Active VLF Size (MB)',
COUNT(l.database_id)-SUM(CAST(vlf_active AS INT)) AS 'In-active VLF',
SUM(vlf_size_mb)-SUM(vlf_active*vlf_size_mb) AS 'In-active VLF Size (MB)'
FROM sys.databases s
CROSS APPLY sys.dm_db_log_info(s.database_id) l
GROUP BY [name], s.database_id
ORDER BY 'VLF Count' DESC
GO

#Commvault Backups:
select 
server_name,database_name, backup_start_date,backup_finish_date
,case 
       type
              when 'D' Then 'Full Backup'
              when 'L' Then 'Tranlog Backup'
              when 'I' Then 'Differential Backup'
              else 'Other Type: ' + type
       end as Backyp_Type
,user_name
from msdb.dbo.backupset 
where user_name = 'NA\xsCVSqlBackup' 
order by backup_start_date desc

Ref:
https://ittutorial.org/sql-server-dba-scripts-all-in-one-useful-database-administration-scripts/
SYSADMIN Permission Missing:
https://deepinthecode.com/2014/05/23/creating-system-admin-login-sql-server-using-command-line/
http://sqlserverandme.blogspot.com/2014/09/troubleshooting-memory-related-issues.html
https://www.red-gate.com/simple-talk/sql/performance/tune-your-indexing-strategy-with-sql-server-dmvs/
Disk Usage:
select  
  volume_letter = UPPER(vs.volume_mount_point) 
, volume_name = vs.logical_volume_name 
, file_system_type 
, drive_size_GB = MAX(CONVERT(decimal(19,2), vs.total_bytes/1024./1024./1024. )) 
 , drive_free_space_GB = MAX(CONVERT(decimal(19,2), vs.available_bytes/1024./1024./1024. )) 
, drive_percent_free = MAX(CONVERT(decimal(5,2), vs.available_bytes * 100.0 / vs.total_bytes)) 
FROM 
sys.master_files AS f CROSS APPLY 
sys.dm_os_volume_stats(f.database_id, f.file_id) vs --only return volumes where there is database file (data or log) 
GROUP BY vs.volume_mount_point, vs.file_system_type, vs.logical_volume_name 
 ORDER BY volume_letter  

--Discover indexes that aren't helping reads but still hurting writes 
--Does not show tables that have never been written to 

 
SELECT  DatabaseName		= d.name 
,	s.object_id 
,	TableName 			= ' [' + sc.name + '].[' + o.name + ']' 
,   IndexName			= i.name 
,   s.user_seeks 
,   s.user_scans 
,   s.user_lookups 
,   s.user_updates 
,	ps.row_count 
,	SizeMb				= cast((ps.in_row_reserved_page_count*8.)/1024. as decimal(19,2)) 
,	s.last_user_lookup 
,	s.last_user_scan 
,	s.last_user_seek 
,	s.last_user_update 
,	Partition_Schema_Name = psch.[name] 
,	Partition_Number = pr.partition_number 
,	[tSQL]	= '--caution! DROP INDEX [' + i.name + '] ON [' + sc.name + '].[' + o.name + ']' --caution!! 
--select object_name(object_id), *  
FROM	sys.dm_db_index_usage_stats s  
 INNER JOIN sys.objects o 
	 ON o.object_id=s.object_id 
inner join sys.schemas sc 
	on sc.schema_id = o.schema_id 
INNER JOIN sys.indexes i 
     ON i.object_id = s.object_id 
          AND i.index_id = s.index_id 
left outer join sys.partitions pr  
	on pr.object_id = i.object_id  
	and pr.index_id = i.index_id 
	left outer join sys.dm_db_partition_stats ps 
		on ps.object_id = i.object_id 
		and ps.partition_id = pr.partition_id 
	left outer join sys.partition_schemes psch  
		on psch.data_space_id = i.data_space_id 
	inner join sys.databases d 
		on s.database_id = d.database_id 
		and db_name() = d.name 
WHERE 1=1  
--Strongly recommended filters 
and o.is_ms_shipped = 0 
and o.type_desc = 'USER_TABLE' 
and i.type_desc = 'NONCLUSTERED' 
and is_unique = 0 
and is_primary_key = 0 
and is_unique_constraint = 0 

 
--Optional filters 
--and user_updates / 50. > (user_seeks + user_scans + user_lookups ) --arbitrary 
--and o.name in ('ContactBase') 
--and o.name not like '%cascade%' 
--and (ps.in_row_reserved_page_count) > 1280 --10mb 
order by user_seeks + user_scans + user_lookups  asc,  s.user_updates desc; --most useless indexes show up first 

Memory stats monitoring:
select  
p.InstanceName 
,	c.Version  
,	'LogicalCPUCount'		= os.cpu_count 
,	Server_Physical_Mem_MB = os.[Server Physical Mem (MB)] -- SQL2012+ only 
,	Min_Server_Mem_MB = c.[Min_Server_Mem_MB] 
,	Max_Server_Mem_MB = c.[Max_Server_Mem_MB] --2147483647 means unlimited, just like it shows in SSMS 
,	p.PLE_s --300s is only an arbitrary rule for smaller memory servers (<16gb), for larger, it should be baselined and measured. 
,	'Churn (MB/s)'			=	cast((p.Total_Server_Mem_GB)/1024./NULLIF(p.PLE_s,0) as decimal(19,2)) 
,	Server_Available_physical_mem_GB = (SELECT cast(available_physical_memory_kb / 1024. / 1024. as decimal(19,2)) from sys.dm_os_sys_memory)  
,	SQL_Physical_memory_in_use_GB = (SELECT cast(physical_memory_in_use_kb / 1024. / 1024. as decimal(19,2)) from sys.dm_os_process_memory) 
,	p.Total_Server_Mem_GB --May be more or less than memory_in_use  
,	p.Target_Server_Mem_GB	 
,	Target_vs_Total = CASE WHEN p.Total_Server_Mem_GB < p.Target_Server_Mem_GB	  
							THEN 'Target >= Total. SQL wants more memory than it has, or is building up to that point.' 
						ELSE 'Total >= Target. SQL has enough memory to do what it wants.' END 
,	si.LPIM -- Works on SQL 2016 SP1, 2012 SP4+ 
 from( 
select  
InstanceName = @@SERVERNAME  
,	Target_Server_Mem_GB =	max(case counter_name when 'Target Server Memory (KB)' then convert(decimal(19,3), cntr_value/1024./1024.) end) 
,	Total_Server_Mem_GB	=	max(case counter_name when  'Total Server Memory (KB)' then convert(decimal(19,3), cntr_value/1024./1024.) end)  
,	PLE_s	=	max(case counter_name when 'Page life expectancy'  then cntr_value end)  
 --select *  
from sys.dm_os_performance_counters 
 --This only looks at one NUMA node. https://www.sqlskills.com/blogs/paul/page-life-expectancy-isnt-what-you-think/ 
 )  as p 
 inner join (select 'InstanceName' = @@SERVERNAME, Version = @@VERSION,  
			Min_Server_Mem_MB  = max(case when name = 'min server memory (MB)' then convert(bigint, value_in_use) end) , 
		Max_Server_Mem_MB = max(case when name = 'max server memory (MB)' then convert(bigint, value_in_use) end)  
		from sys.configurations) as c on p.InstanceName = c.InstanceName 
inner join (SELECT 'InstanceName' = @@SERVERNAME  
		, cpu_count , hyperthread_ratio AS 'HyperthreadRatio', 
		cpu_count/hyperthread_ratio AS 'PhysicalCPUCount' 
			, 'Server Physical Mem (MB)' = cast(physical_memory_kb/1024. as decimal(19,2))   -- SQL2012+ only 
		FROM sys.dm_os_sys_info ) as os 
on c.InstanceName=os.InstanceName 
 
-- Works on SQL 2016 SP1, 2012 SP4+ 
 cross apply (select LPIM = CASE sql_memory_model_Desc  
					WHEN  'Conventional' THEN 'Lock Pages in Memory privilege is not granted' 
					WHEN 'LOCK_PAGES' THEN 'Lock Pages in Memory privilege is granted' 
				WHEN 'LARGE_PAGES' THEN 'Lock Pages in Memory privilege is granted in Enterprise mode with Trace Flag 834 ON' 
					END from sys.dm_os_sys_info  
			) as si 

DB wise IO Stall
SELECT  DB_NAME(fs.database_id) AS [Database Name] ,
        mf.physical_name ,
        io_stall_read_ms ,
        num_of_reads ,
        CAST(io_stall_read_ms / ( 1.0 + num_of_reads ) AS NUMERIC(10, 1)) AS [avg_read_stall_ms] ,
        io_stall_write_ms ,
        num_of_writes ,
        CAST(io_stall_write_ms / ( 1.0 + num_of_writes ) AS NUMERIC(10, 1)) AS [avg_write_stall_ms] ,
        io_stall_read_ms + io_stall_write_ms AS [io_stalls] ,
        num_of_reads + num_of_writes AS [total_io] ,
        CAST(( io_stall_read_ms + io_stall_write_ms ) / ( 1.0 + num_of_reads
                                                          + num_of_writes ) AS NUMERIC(10,
                                                              1)) AS [avg_io_stall_ms]
FROM    sys.dm_io_virtual_file_stats(NULL, NULL) AS fs
        INNER JOIN sys.master_files AS mf WITH ( NOLOCK ) ON fs.database_id = mf.database_id
                                                             AND fs.[file_id] = mf.[file_id]
ORDER BY avg_io_stall_ms DESC
OPTION  ( RECOMPILE );
IO Wait stall
SELECT TOP 10
        wait_type ,
        max_wait_time_ms wait_time_ms ,
        signal_wait_time_ms ,
        wait_time_ms - signal_wait_time_ms AS resource_wait_time_ms ,
        100.0 * wait_time_ms / SUM(wait_time_ms) OVER ( ) AS percent_total_waits ,
        100.0 * signal_wait_time_ms / SUM(signal_wait_time_ms) OVER ( ) AS percent_total_signal_waits ,
        100.0 * ( wait_time_ms - signal_wait_time_ms )
        / SUM(wait_time_ms) OVER ( ) AS percent_total_resource_waits
FROM    sys.dm_os_wait_stats
WHERE   wait_time_ms > 0 -- remove zero wait_time
        AND wait_type NOT IN -- filter out additional irrelevant waits
( 'SLEEP_TASK', 'BROKER_TASK_STOP', 'BROKER_TO_FLUSH', 'SQLTRACE_BUFFER_FLUSH',
  'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT', 'LAZYWRITER_SLEEP', 'SLEEP_SYSTEMTASK',
  'SLEEP_BPOOL_FLUSH', 'BROKER_EVENTHANDLER', 'XE_DISPATCHER_WAIT',
  'FT_IFTSHC_MUTEX', 'CHECKPOINT_QUEUE', 'FT_IFTS_SCHEDULER_IDLE_WAIT',
  'BROKER_TRANSMITTER', 'FT_IFTSHC_MUTEX', 'KSOURCE_WAKEUP',
  'LAZYWRITER_SLEEP', 'LOGMGR_QUEUE', 'ONDEMAND_TASK_QUEUE',
  'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT', 'BAD_PAGE_PROCESS',
  'DBMIRROR_EVENTS_QUEUE', 'BROKER_RECEIVE_WAITFOR',
  'PREEMPTIVE_OS_GETPROCADDRESS', 'PREEMPTIVE_OS_AUTHENTICATIONOPS', 'WAITFOR',
  'DISPATCHER_QUEUE_SEMAPHORE', 'XE_DISPATCHER_JOIN', 'RESOURCE_QUEUE' )
ORDER BY wait_time_ms DESC
DECLARE @gc VARCHAR(MAX), @gi VARCHAR(MAX); 
WITH BR_Data as ( 
SELECT timestamp, CONVERT(XML, record) as record 
FROM sys.dm_os_ring_buffers 
WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' and record like '%<SystemHealth>%' 
), Extracted_XML as ( 
SELECT timestamp, record.value('(./Record/@id)[1]', 'int') as record_id, 
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'bigint') as SystemIdle, 
record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'bigint') as SQLCPU 
FROM BR_Data 
), CPU_Data as ( 
SELECT record_id, ROW_NUMBER() OVER(ORDER BY record_id) as rn, 
dateadd(ms, -1 * ((SELECT ms_ticks  FROM sys.dm_os_sys_info) - [timestamp]), GETDATE()) as EventTime, 
SQLCPU, SystemIdle, 100 - SystemIdle - SQLCPU as OtherCPU 
FROM Extracted_XML ) 
SELECT @gc = CAST((SELECT  CAST(d1.rn as VARCHAR) + ' ' + CAST(d1.SQLCPU as VARCHAR) + ',' FROM CPU_Data as d1 ORDER BY d1.rn FOR XML PATH('')) as VARCHAR(MAX)), 
@gi = CAST((SELECT  CAST(d1.rn as VARCHAR) + ' ' + CAST(d1.OtherCPU as VARCHAR) + ',' FROM CPU_Data as d1 ORDER BY d1.rn FOR XML PATH('')) as VARCHAR(MAX)) 
OPTION (RECOMPILE); 
SELECT CAST('LINESTRING(' + LEFT(@gc,LEN(@gc)-1) + ')' as GEOMETRY), 'SQL CPU %' as Measure 
UNION ALL 
SELECT CAST('LINESTRING(1 100,2 100)' as GEOMETRY), '' 
UNION ALL 
SELECT CAST('LINESTRING(' + LEFT(@gi,LEN(@gi)-1) + ')' as GEOMETRY), 'Other CPU %'; 


URL:
http://slavasql.blogspot.ru/2016/03/sql-server-cpu-utilization-in-graphical.html


http://dbadiaries.com/category/all-articles/sql-server-performance/page/3/

#Monitor CPU and Memory usage for all SQL Server instances
WITH SQLProcessCPU
AS(
   SELECT TOP(30) SQLProcessUtilization AS 'CPU_Usage', ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) AS 'row_number'
   FROM ( 
         SELECT 
           record.value('(./Record/@id)[1]', 'int') AS record_id,
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') AS [SystemIdle],
           record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') AS [SQLProcessUtilization], 
           [timestamp] 
         FROM ( 
              SELECT [timestamp], CONVERT(xml, record) AS [record] 
              FROM sys.dm_os_ring_buffers 
              WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
              AND record LIKE '%<SystemHealth>%'
              ) AS x 
        ) AS y
) 

SELECT 
   SERVERPROPERTY('SERVERNAME') AS 'Instance',
   (SELECT value_in_use FROM sys.configurations WHERE name like '%max server memory%') AS 'Max Server Memory',
   (SELECT physical_memory_in_use_kb/1024 FROM sys.dm_os_process_memory) AS 'SQL Server Memory Usage (MB)',
   (SELECT total_physical_memory_kb/1024 FROM sys.dm_os_sys_memory) AS 'Physical Memory (MB)',
   (SELECT available_physical_memory_kb/1024 FROM sys.dm_os_sys_memory) AS 'Available Memory (MB)',
   (SELECT system_memory_state_desc FROM sys.dm_os_sys_memory) AS 'System Memory State',
   (SELECT [cntr_value] FROM sys.dm_os_performance_counters WHERE [object_name] LIKE '%Manager%' AND [counter_name] = 'Page life expectancy') AS 'Page Life Expectancy',
   (SELECT AVG(CPU_Usage) FROM SQLProcessCPU WHERE row_number BETWEEN 1 AND 30) AS 'SQLProcessUtilization30',
   (SELECT AVG(CPU_Usage) FROM SQLProcessCPU WHERE row_number BETWEEN 1 AND 15) AS 'SQLProcessUtilization15',
   (SELECT AVG(CPU_Usage) FROM SQLProcessCPU WHERE row_number BETWEEN 1 AND 10) AS 'SQLProcessUtilization10',
   (SELECT AVG(CPU_Usage) FROM SQLProcessCPU WHERE row_number BETWEEN 1 AND 5)  AS 'SQLProcessUtilization5',
   GETDATE() AS 'Data Sample Timestamp'

https://www.mssqltips.com/sqlservertip/5724/monitor-cpu-and-memory-usage-for-all-sql-server-instances-using-powershell/


https://www.mssqltips.com/sqlservertip/6096/sql-server-database-activity-based-on-transaction-log-backup-size/

