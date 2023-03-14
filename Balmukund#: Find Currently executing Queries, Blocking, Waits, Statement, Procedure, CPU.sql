/*This is one of my all time favorite script which I use most of the time in troubleshooting performance issues on live systems. This helps in findings below:

What is the performance bottleneck?
Is there any blocking? If yes, who is the blocker?
What are the queries which are executing currently?
What is the name of the stored procedure running currently?
Which statement in stored procedure is getting executed right now?
Who is consuming CPU right now? What are the high CPU queries?
Who is doing lots of IO right now?
Column heading is self-explanatory. You need to adjust ORDER BY clause based on your need. In below query, I am showing top CPU consumers at the top. (Thanks for Ghufran (f) for adding more columns)
*/
SELECT s.session_id
    ,r.STATUS
    ,r.blocking_session_id AS 'blocked_by'
    ,r.wait_type
    ,r.wait_resource
    ,CONVERT(VARCHAR, DATEADD(ms, r.wait_time, 0), 8) AS 'wait_time'
    ,r.cpu_time
    ,r.logical_reads
    ,r.reads
    ,r.writes
    ,CONVERT(varchar, (r.total_elapsed_time/1000 / 86400))+ 'd ' +
     CONVERT(VARCHAR, DATEADD(ms, r.total_elapsed_time, 0), 8)   AS 'elapsed_time'
    ,CAST((
            '<?query --  ' + CHAR(13) + CHAR(13) + Substring(st.TEXT, (r.statement_start_offset / 2) + 1, (
                    (
                        CASE r.statement_end_offset
                            WHEN - 1
                                THEN Datalength(st.TEXT)
                            ELSE r.statement_end_offset
                            END - r.statement_start_offset
                        ) / 2
                    ) + 1) + CHAR(13) + CHAR(13) + '--?>'
            ) AS XML) AS 'query_text'
    ,COALESCE(QUOTENAME(DB_NAME(st.dbid)) + N'.' + QUOTENAME(OBJECT_SCHEMA_NAME(st.objectid, st.dbid)) + N'.' + 
     QUOTENAME(OBJECT_NAME(st.objectid, st.dbid)), '') AS 'stored_proc'
    --,qp.query_plan AS 'xml_plan'  -- uncomment (1) if you want to see plan
    ,r.command
    ,s.login_name
    ,s.host_name
    ,s.program_name
    ,s.host_process_id
    ,s.last_request_end_time
    ,s.login_time
    ,r.open_transaction_count
FROM sys.dm_exec_sessions AS s
INNER JOIN sys.dm_exec_requests AS r ON r.session_id = s.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) AS st
--OUTER APPLY sys.dm_exec_query_plan(r.plan_handle) AS qp -- uncomment (2) if you want to see plan
WHERE r.wait_type NOT LIKE 'SP_SERVER_DIAGNOSTICS%'
    OR r.session_id != @@SPID
ORDER BY r.cpu_time DESC
    ,r.STATUS
    ,r.blocking_session_id
    ,s.session_id
