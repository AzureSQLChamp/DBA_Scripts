-- Step 4.1 related
sp_replcounters
GO

SELECT  
       SessionId    = s.session_id,  
       App            = ISNULL(s.program_name, N'')
    FROM sys.dm_exec_sessions s
WHERE s.program_name LIKE '%LogReader%'

CREATE EVENT SESSION [LogReaderMonitor] ON SERVER
ADD EVENT sqlos.wait_completed(
   ACTION(package0.callstack)
   WHERE ([sqlserver].[session_id]=(123))),
ADD EVENT sqlos.wait_info_external(
   ACTION(package0.callstack)
   WHERE (([opcode]=('End')) AND ([sqlserver].[session_id]=(123)))),
ADD EVENT sqlserver.rpc_completed(
   ACTION(package0.callstack)
   WHERE ([sqlserver].[session_id]=(123)))
ADD TARGET package0.event_file(SET filename=N'C:\Temp\logreader_reader_track',max_file_size=(256),max_rollover_files=(5))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO

-- Step 4.2 related
-- Get publisher db id
USE distribution
GO
SELECT * FROM dbo.MSpublisher_databases

-- Get commands we are at
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
GO
BEGIN TRAN
USE distribution 
go 
EXEC Sp_browsereplcmds
@xact_seqno_start = 'xact_seqno', 
@xact_seqno_end = 'xact_seqno', 
@publisher_database_id = PUBLISHERDB_ID
COMMIT TRAN
GO

SELECT  
       SessionId    = s.session_id,  
       App            = ISNULL(s.program_name, N'')
    FROM sys.dm_exec_sessions s
WHERE s.program_name LIKE '%LogReader%'

CREATE EVENT SESSION [logreader_writer_track] ON SERVER 
ADD EVENT sqlos.wait_completed(
    ACTION(package0.callstack)
    WHERE ([sqlserver].[session_id]=(64))),  -- Change session id to log reader writer session id
ADD EVENT sqlos.wait_info_external(
    ACTION(package0.callstack)
    WHERE (([opcode]=('End')) AND ([sqlserver].[session_id]=(64)))), -- Change session id to log reader writer session id
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(package0.event_sequence,sqlserver.plan_handle,sqlserver.session_id,sqlserver.transaction_id)
    WHERE ([sqlserver].[session_id]=(64)))  -- Change session id to log reader writer session id
ADD TARGET package0.event_file(SET filename=N'C:\Temp\logreader_writer_track',max_file_size=(256),max_rollover_files=(5))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)

-- Step 4.3 related
SELECT  
       SessionId    = s.session_id,  
       App            = ISNULL(s.program_name, N'')  
    FROM sys.dm_exec_sessions s LEFT OUTER JOIN sys.dm_exec_connections c ON (s.session_id = c.session_id) 
WHERE (select text from sys.dm_exec_sql_text(c.most_recent_sql_handle)) LIKE '%sp_MSget_repl_command%'

CREATE EVENT SESSION [distributor_writer_track] ON SERVER 
ADD EVENT sqlos.wait_completed(
    ACTION(package0.callstack)
    WHERE ([sqlserver].[session_id]=(64))),  -- Change session id to dist agent session id
ADD EVENT sqlos.wait_info_external(
    ACTION(package0.callstack)
    WHERE (([opcode]=('End')) AND ([sqlserver].[session_id]=(64)))), -- Change session id to dist agent session id
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(package0.event_sequence,sqlserver.plan_handle,sqlserver.session_id,sqlserver.transaction_id)
    WHERE ([sqlserver].[session_id]=(64)))  -- Change session id to dist agent session id
ADD TARGET package0.event_file(SET filename=N'C:\Temp\distributor_reader_track',max_file_size=(256),max_rollover_files=(5))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)

-- Step 4.4 related
SELECT  
       SessionId    = s.session_id,  
       App            = ISNULL(s.program_name, N'')
    FROM sys.dm_exec_sessions s
WHERE s.program_name LIKE '%publish%'
GO

CREATE EVENT SESSION [distributor_writer_track] ON SERVER 
ADD EVENT sqlos.wait_completed(
    ACTION(package0.callstack,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[client_app_name]=N'SQLVM4-TRANSACR_AdventureWorksLT_test_table_pub' AND [package0].[greater_than_uint64]([duration],(0)))),
ADD EVENT sqlos.wait_info_external(
    ACTION(package0.callstack,sqlserver.session_id,sqlserver.sql_text)
    WHERE ([sqlserver].[client_app_name]=N'SQLVM4-TRANSACR_AdventureWorksLT_test_table_pub' AND [package0].[greater_than_uint64]([duration],(0)))),
ADD EVENT sqlserver.sp_statement_completed(
    ACTION(package0.event_sequence,sqlserver.plan_handle,sqlserver.session_id,sqlserver.transaction_id)
    WHERE ([sqlserver].[client_app_name]=N'SQLVM4-TRANSACR_AdventureWorksLT_test_table_pub'))
ADD TARGET package0.event_file(SET filename=N'C:\Temp\logreader_writer_track',max_file_size=(5),max_rollover_files=(5))
WITH (MAX_MEMORY=8192 KB,EVENT_RETENTION_MODE=ALLOW_MULTIPLE_EVENT_LOSS,MAX_DISPATCH_LATENCY=30 SECONDS,MAX_EVENT_SIZE=0 KB,MEMORY_PARTITION_MODE=NONE,TRACK_CAUSALITY=ON,STARTUP_STATE=OFF)
GO 
