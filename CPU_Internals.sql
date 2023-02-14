--SQL Server Database wise CPU Utilization
/*****	Script: Database Wise CPU Utilization report *****/
/*****	Support: SQL Server 2008 and Above *****/
/*****	TestedOn: SQL Server 2008 R2 and 2014 *****/
/*****	Output: 
SNO: Serial Number
DBName: Databse Name 
CPU_Time(Ms): CPU Time in Milliseconds
CPUPercent: Let’s say this instance is using 50% CPU and one of the database is      using 80%. It means the actual CPU usage from the database is calculated as: (80 / 100) * 50 = 40 %
*****/

WITH DB_CPU AS
(SELECT	DatabaseID, 
		DB_Name(DatabaseID)AS [DatabaseName], 
		SUM(total_worker_time)AS [CPU_Time(Ms)] 
FROM	sys.dm_exec_query_stats AS qs 
CROSS APPLY(SELECT	CONVERT(int, value)AS [DatabaseID]  
			FROM	sys.dm_exec_plan_attributes(qs.plan_handle)  
			WHERE	attribute =N'dbid')AS epa GROUP BY DatabaseID) 
SELECT	ROW_NUMBER()OVER(ORDER BY [CPU_Time(Ms)] DESC)AS [SNO], 
	DatabaseName AS [DBName], [CPU_Time(Ms)], 
	CAST([CPU_Time(Ms)] * 1.0 /SUM([CPU_Time(Ms)]) OVER()* 100.0 AS DECIMAL(5, 2))AS [CPUPercent] 
FROM	DB_CPU 
WHERE	DatabaseID > 4 -- system databases 
	AND DatabaseID <> 32767 -- ResourceDB 
ORDER BY SNO OPTION(RECOMPILE); 

--Find Top 20 Costliest Queries – High CPU
/*****	Script: Top 20 Stored Procedures using High CPU *****/
/*****	Support: SQL Server 2008 and Above *****/
/*****	Tested On: SQL Server 2008 R2 and 2014 *****/
/*****	Output: Queries, CPU, Elapsed Times, Ms and S ****/
SELECT TOP (20)
    st.text AS Query,
    qs.execution_count,
    qs.total_worker_time AS Total_CPU,
    total_CPU_inSeconds = --Converted from microseconds
    qs.total_worker_time/1000000,
    average_CPU_inSeconds = --Converted from microseconds
    (qs.total_worker_time/1000000) / qs.execution_count,
    qs.total_elapsed_time,
    total_elapsed_time_inSeconds = --Converted from microseconds
    qs.total_elapsed_time/1000000,
    qp.query_plan
FROM sys.dm_exec_query_stats AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS apply sys.dm_exec_query_plan (qs.plan_handle) AS qp
ORDER BY qs.total_worker_time DESC OPTION (RECOMPILE);

Ref:
http://udayarumilli.com/sql-script-monitor-cpu-utilization-2/
https://logicalread.com/troubleshoot-high-cpu-sql-server-pd01/#.XTGMUzZPrcc
http://dba-datascience.com/high-cpu-usage-sql-server/
https://blogs.msdn.microsoft.com/sqlsakthi/2011/03/13/max-worker-threads-and-when-you-should-change-it/



