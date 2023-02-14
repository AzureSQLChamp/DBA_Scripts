--Script to Monitor SQL Server Memory Usage: Database Wise Buffer Usage
/**************************************************************/
--Script: Database Wise Buffer Usage
--Works On: 2008, 2008 R2, 2012, 2014, 2016
/**************************************************************/

DECLARE @total_buffer INT;
SELECT  @total_buffer = cntr_value 
FROM   sys.dm_os_performance_counters
WHERE  RTRIM([object_name]) LIKE '%Buffer Manager' 
       AND counter_name = 'Database Pages';

;WITH DBBuffer AS
(
SELECT  database_id,
        COUNT_BIG(*) AS db_buffer_pages,
        SUM (CAST ([free_space_in_bytes] AS BIGINT)) / (1024 * 1024) AS [MBEmpty]
FROM    sys.dm_os_buffer_descriptors
GROUP BY database_id
)
SELECT
       CASE [database_id] WHEN 32767 THEN 'Resource DB' ELSE DB_NAME([database_id]) END AS 'db_name',
       db_buffer_pages AS 'db_buffer_pages',
       db_buffer_pages / 128 AS 'db_buffer_Used_MB',
       [mbempty] AS 'db_buffer_Free_MB',
       CONVERT(DECIMAL(6,3), db_buffer_pages * 100.0 / @total_buffer) AS 'db_buffer_percent'
FROM   DBBuffer
ORDER BY db_buffer_Used_MB DESC;

