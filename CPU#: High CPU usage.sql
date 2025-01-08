--- Step 2 commands
$serverName = $env:COMPUTERNAME
$Counters = @(
    ("\\$serverName" + "\Process(sqlservr*)\% User Time"), ("\\$serverName" + "\Process(sqlservr*)\% Privileged Time")
)
Get-Counter -Counter $Counters -MaxSamples 30 | ForEach {
    $_.CounterSamples | ForEach {
        [pscustomobject]@{
            TimeStamp = $_.TimeStamp
            Path = $_.Path
            Value = ([Math]::Round($_.CookedValue, 3))
        }
        Start-Sleep -s 2
    }
}

-- Step 3 queries
DECLARE @init_sum_cpu_time int,
        @utilizedCpuCount int 
--get CPU count used by SQL Server
SELECT @utilizedCpuCount = COUNT( * )
FROM sys.dm_os_schedulers
WHERE status = 'VISIBLE ONLINE' 
--calculate the CPU usage by queries OVER a 5 sec interval 
SELECT @init_sum_cpu_time = SUM(cpu_time) FROM sys.dm_exec_requests
WAITFOR DELAY '00:00:05'
SELECT CONVERT(DECIMAL(5,2), ((SUM(cpu_time) - @init_sum_cpu_time) / (@utilizedCpuCount * 5000.00)) * 100) AS [CPU from Queries as Percent of Total CPU Capacity] 
FROM sys.dm_exec_requests

----- Query 1: Data at session level
SELECT TOP 10 s.session_id,
           r.status,
           r.cpu_time,
           r.logical_reads,
           r.reads,
           r.writes,
           r.total_elapsed_time / (1000 * 60) 'Elaps M',
           SUBSTRING(st.TEXT, (r.statement_start_offset / 2) + 1,
           ((CASE r.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.TEXT)
                ELSE r.statement_end_offset
            END - r.statement_start_offset) / 2) + 1) AS statement_text,
           COALESCE(QUOTENAME(DB_NAME(st.dbid)) + N'.' + QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) 
           + N'.' + QUOTENAME(OBJECT_NAME(st.objectid, st.dbid)), '') AS command_text,
           r.command,
           s.login_name,
           s.host_name,
           s.program_name,
           s.last_request_end_time,
           s.login_time,
           r.open_transaction_count
FROM sys.dm_exec_sessions AS s
JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id CROSS APPLY sys.Dm_exec_sql_text(r.sql_handle) AS st
WHERE r.session_id != @@SPID
ORDER BY r.cpu_time DESC

----- Query 2: Data at request and task level
SELECT
r.session_id,
t.task_address,
task_state,
start_time,
--status as request_status,
database_id,
blocking_session_id,
wait_type,
wait_time,
wait_resource,
cpu_time,
total_elapsed_time,
r.scheduler_id,
reads as number_of_reads,
writes as number_of_writes,
logical_reads as number_of_logical_reads,
SUBSTRING (REPLACE (REPLACE (SUBSTRING (ST.text, (r.statement_start_offset/2) + 1, 
       ((CASE statement_end_offset
           WHEN -1
           THEN DATALENGTH(ST.text)  
           ELSE r.statement_end_offset
         END - r.statement_start_offset)/2) + 1) , CHAR(10), ' '), CHAR(13), ' '), 
      1, 512)  AS statement_text
FROM sys.dm_exec_requests r
LEFT JOIN sys.dm_os_tasks t ON t.session_id = r.session_id AND t.task_address = t.task_address
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS ST

----- Query 3: To find how many tasks are being allocated to each CPU:

SELECT 
scheduler_id,
cpu_id,
status,
is_online,
current_tasks_count,
runnable_tasks_count,
current_workers_count,
pending_disk_io_count
FROM sys.dm_os_schedulers

-- Extended events
CREATE EVENT SESSION [cpu_performance_track_2017_2019] ON SERVER 
ADD EVENT sqlserver.error_reported(
    ACTION(sqlserver.session_id,sqlserver.sql_text)),
ADD EVENT sqlserver.query_post_execution_plan_profile (ACTION(sqlos.scheduler_id,sqlserver.database_id,sqlserver.is_system,sqlserver.plan_handle,sqlserver.query_hash_signed,sqlserver.query_plan_hash_signed,sqlserver.server_instance_name,sqlserver.session_id,sqlserver.session_nt_username,sqlserver.sql_text)),
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(package0.event_sequence,package0.last_error,sqlserver.context_info,sqlserver.plan_handle,sqlserver.session_id,sqlserver.transaction_id)),
ADD EVENT sqlserver.sp_statement_starting(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.sql_batch_completed(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.sql_batch_starting(
    ACTION(sqlserver.session_id)),
ADD EVENT sqlserver.sql_statement_completed(SET collect_statement=(1)
    ACTION(package0.last_error,sqlserver.context_info,sqlserver.session_id)),
ADD EVENT sqlserver.sql_statement_starting(SET collect_statement=(1)
    ACTION(sqlserver.session_id))
ADD TARGET package0.event_file(SET filename=N'C:\Temp\performance_track',max_file_size=(500),max_rollover_files=(5))
WITH (MAX_MEMORY=4096 KB,EVENT_RETENTION_MODE=ALLOW_SINGLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=OFF,STARTUP_STATE=OFF)
GO

--Perfmon command
Logman.exe create counter PerfLog-Short -o "C:\temp\%ComputerName%_PerfLog-Short.blg" -f bincirc -v mmddhhmm -max 500 -c "\LogicalDisk(*)\*" "\Memory\*" "\.NET CLR Memory(*)\*" "\Cache\*" "\Network Interface(*)\*" "\Paging File(*)\*" "\PhysicalDisk(*)\*" "\Processor(*)\*" "\Processor Information(*)\*" "\Process(*)\*" "\Thread(*)\*" "\Redirector\*" "\Server\*" "\System\*" "\Server Work Queues(*)\*" "\Terminal Services\*" -si 00:00:01

To start:
Logman.exe start PerfLog-Short

To finish:
Logman.exe stop PerfLog-Short


https://udayarumilli.com/sql-script-monitor-cpu-utilization-2/
