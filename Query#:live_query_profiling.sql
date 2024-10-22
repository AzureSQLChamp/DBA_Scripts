DECLARE 
    @session_id smallint = 93;

SELECT
    is_parent = 
        CASE
             WHEN dot.task_address IS NULL
             THEN 1
             ELSE 0
        END,
    dot.task_state,
    dot.exec_context_id,
    dot2.os_thread_id,
    dot.scheduler_id,
    deqp.thread_id,
    deqp.node_id,
    deqp.row_count,
    dow.state,
    dowt.wait_duration_ms,
    dowt.wait_type,
    dow.last_wait_type,
    sws.top_waits,
    deqp.physical_operator_name,
    dowt.resource_description
FROM sys.dm_os_tasks AS dot
JOIN sys.dm_os_workers AS dow
  ON dow.worker_address = dot.worker_address
JOIN sys.dm_os_threads AS dot2
  ON dot2.thread_address = dow.thread_address
OUTER APPLY
(
    SELECT
        deqp.*
    FROM sys.dm_exec_query_profiles AS deqp
    WHERE deqp.session_id = dot.session_id
    AND   deqp.request_id = dot.request_id
    AND   deqp.task_address = dot.task_address
) AS deqp
OUTER APPLY
(
    SELECT
        dowt.*
    FROM sys.dm_os_waiting_tasks AS dowt
    WHERE dowt.session_id = dot.session_id
    AND   dowt.exec_context_id = dot.exec_context_id
    ORDER BY
        dowt.wait_duration_ms DESC 
        OFFSET 0 ROWS 
        FETCH FIRST 1 ROW ONLY
) AS dowt
OUTER APPLY
(
    SELECT
        top_waits = 
            STUFF
            (
                (
                   SELECT TOP (5)
                        ', ' +
                        sws.wait_type +
                        ' (' +
                        CONVERT
                        (
                            varchar(20),
                            SUM
                            (
                                CONVERT
                                (
                                    bigint,
                                    sws.wait_time_ms
                                )
                            )
                        ) +
                        ' ms)'
                   FROM sys.dm_exec_session_wait_stats AS sws
                   WHERE sws.session_id = dot.session_id
                   GROUP BY 
                       sws.wait_type
                   HAVING
                       SUM(sws.wait_time_ms) > 500 
                   ORDER BY
                       SUM(sws.wait_time_ms) DESC 
                   FOR XML 
                       PATH(''), 
                       TYPE
                ).value('./text()[1]', 'varchar(max)'),
                1,
                2,
                ''
            )
) AS sws
WHERE 
(
     dot.session_id = @session_id 
  OR @session_id IS NULL
)
ORDER BY
    deqp.node_id,
    dot.exec_context_id
OPTION(RECOMPILE);
