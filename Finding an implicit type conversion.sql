/*
Investigating the problem
The “non-SARGable predicate” is just one of many query-related mistakes that can spell trouble for SQL Server performance. In cases where it forces the optimizer to
compile an execution plan containing scans of large clustered indexes, or tables, it degrades performance.

If the optimizer is forced to scan every row in a 500K-row table, just to return small number of them, then it will cause avoidable resource pressure.
Affected queries will require significantly more CPU processing time, and the optimizer may choose to use parallel execution, speeding the execution of what 
should be simple and fast query across multiple cores. This will often cause blocking of other queries. Also, many more pages will need to be read in and out of 
memory, potentially causing both IO and memory ‘bottleneck’.

To detect whether implicit conversions are part of the problem, SQL Server provides two tools:

The sys.dm_exec_cached_plans DMV, and other DMVs that provide query plan metadata
The sqlserver.plan_affecting_convert event in Extended Events
*/

--Using the plan cache

DECLARE @dbname SYSNAME = QUOTENAME(DB_NAME());
WITH XMLNAMESPACES
   (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT
   stmt.value('(@StatementText)[1]', 'varchar(max)') AS SQL_Batch,
   + t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)') +'.'
   + t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)')+ '.'
   + t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)') AS The_ColumnReference,
   ic.DATA_TYPE AS ConvertFrom,
   ic.CHARACTER_MAXIMUM_LENGTH AS ConvertFromLength,
   t.value('(@DataType)[1]', 'varchar(128)') AS ConvertTo,
   t.value('(@Length)[1]', 'int') AS ConvertToLength,
   query_plan
FROM sys.dm_exec_cached_plans AS cp
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS qp
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS batch(stmt)
CROSS APPLY stmt.nodes('.//Convert[@Implicit="1"]') AS n(t)
JOIN INFORMATION_SCHEMA.COLUMNS AS ic
   ON QUOTENAME(ic.TABLE_SCHEMA) = t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)')
   AND QUOTENAME(ic.TABLE_NAME) = t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)')
   AND ic.COLUMN_NAME = t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)')
WHERE t.exist('ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]') = 1

/*
Extended Events
My preferred way to spot this problem is to run an extended events session that captures the sqlserver.plan_affecting_convert event. 
The great thing about running these is that those places where an implicit conversion has ruined a good execution plan instantly appear when you run the code.

To prevent any embarrassment on the part of the database developer, it is far better to do this in development, so this is one of the extended event sessions
I like to have ready on the development server.

Here is the code that defines the extended events session. it is set to just filter for plan-affecting implicit conversions on AdventureWorks2014. 
You’ll want to change that, obviously, for your database.
*/

IF EXISTS --if the session already exists, then delete it. We are assuming you've changed something
  (
  SELECT * FROM sys.server_event_sessions
    WHERE server_event_sessions.name = 'Find_Implicit_Conversions_Affecting_Performance'
  )
  DROP EVENT SESSION Find_Implicit_Conversions_Affecting_Performance ON SERVER;
GO
CREATE EVENT SESSION Find_Implicit_Conversions_Affecting_Performance ON SERVER 
  ADD EVENT sqlserver.plan_affecting_convert(
    ACTION(sqlserver.database_name,sqlserver.username,sqlserver.session_nt_username,sqlserver.sql_text)
    WHERE ([sqlserver].[database_name]=N'AdventureWorks2016'))
      ADD TARGET package0.ring_buffer
      WITH (STARTUP_STATE=ON)
GO
ALTER EVENT SESSION Find_Implicit_Conversions_Affecting_Performance ON SERVER STATE = START;

--Now we can query it for all plan_affecting_convert events, and include the text of the SQL batch that caused the problem
DECLARE @Target_Data XML =
          (
          SELECT TOP 1 Cast(xet.target_data AS XML) AS targetdata
            FROM sys.dm_xe_session_targets AS xet
              INNER JOIN sys.dm_xe_sessions AS xes
                ON xes.address = xet.event_session_address
            WHERE xes.name = 'Find_Implicit_Conversions_Affecting_Performance'
              AND xet.target_name = 'ring_buffer'
          );
SELECT 
CONVERT(datetime2,
        SwitchOffset(CONVERT(datetimeoffset,the.event_data.value('(@timestamp)[1]', 'datetime2')),
        DateName(TzOffset, SYSDATETIMEOFFSET()))) AS datetime_local,
the.event_data.value('(data[@name="compile_time"]/value)[1]', 'nvarchar(5)') AS [Compile_Time],
CASE the.event_data.value('(data[@name="convert_issue"]/value)[1]', 'int')
                  WHEN 1 THEN 'cardinality estimate'ELSE 'seek plan'END  AS [Convert_Issue],
the.event_data.value('(data[@name="expression"]/value)[1]', 'nvarchar(max)') AS [Expression],
the.event_data.value('(action[@name="database_name"]/value)[1]', 'sysname') AS [Database],
the.event_data.value('(action[@name="username"]/value)[1]', 'sysname') AS Username,
the.event_data.value('(action[@name="session_nt_username"]/value)[1]', 'sysname') AS [Session NT Username],
the.event_data.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [SQL Context]
FROM @Target_Data.nodes('//RingBufferTarget/event') AS the (event_data)
