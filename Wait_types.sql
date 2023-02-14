SELECT dm_ws.wait_duration_ms,
dm_ws.wait_type,
dm_es.status,
dm_t.TEXT,
dm_qp.query_plan,
dm_ws.session_ID,
dm_es.cpu_time,
dm_es.memory_usage,
dm_es.logical_reads,
dm_es.total_elapsed_time,
dm_es.program_name,
DB_NAME(dm_r.database_id) DatabaseName,
-- Optional columns
dm_ws.blocking_session_id,
dm_r.wait_resource,
dm_es.login_name,
dm_r.command,
dm_r.last_wait_type
FROM sys.dm_os_waiting_tasks dm_ws
INNER JOIN sys.dm_exec_requests dm_r ON dm_ws.session_id = dm_r.session_id
INNER JOIN sys.dm_exec_sessions dm_es ON dm_es.session_id = dm_r.session_id
CROSS APPLY sys.dm_exec_sql_text (dm_r.sql_handle) dm_t
CROSS APPLY sys.dm_exec_query_plan (dm_r.plan_handle) dm_qp
WHERE dm_es.is_user_process = 1
 GO

WITH Waits AS 
 ( 
 SELECT  
   wait_type,  
   wait_time_ms / 1000. AS wait_time_s, 
   100. * wait_time_ms / SUM(wait_time_ms) OVER() AS pct, 
   ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS rn 
 FROM sys.dm_os_wait_stats 
 WHERE wait_type  
   NOT IN 
     ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
   'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 
   'CLR_AUTO_EVENT', 'CLR_MANUAL_EVENT') 
   ) -- filter out additional irrelevant waits 
    
SELECT W1.wait_type, 
 CAST(W1.wait_time_s AS DECIMAL(12, 2)) AS wait_time_s, 
 CAST(W1.pct AS DECIMAL(12, 2)) AS pct, 
 CAST(SUM(W2.pct) AS DECIMAL(12, 2)) AS running_pct 
FROM Waits AS W1 
 INNER JOIN Waits AS W2 ON W2.rn <= W1.rn 
GROUP BY W1.rn,  
 W1.wait_type,  
 W1.wait_time_s,  
 W1.pct 
HAVING SUM(W2.pct) - W1.pct < 95; -- percentage threshold;


