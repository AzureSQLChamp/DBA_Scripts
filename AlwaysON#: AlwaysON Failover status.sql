--exec sp_cycle_errorlog
GO
sp_readerrorlog 0,1,'The state of the local availability replica','AAG1'
GO
--Powershell Script
    Get-winEvent -ComputerName ListnerName -filterHashTable @{logname ='Microsoft-Windows-FailoverClustering/Operational'; id=1641}| ft -AutoSize -Wrap 
--Query to find out if any failover happened in the last 30 minutes
create table #errormsg(duration datetime,errornum int,dbmessage varchar(max))
DECLARE @tags3 VARCHAR(5000)SET @tags3  = (SELECT CAST( t.target_data AS XML ).value('(EventFileTarget/File/@name)[1]', 'VARCHAR(MAX)') FROM sys.dm_xe_sessions s INNER JOIN sys.dm_xe_session_targets t ON s.address = t.event_session_address WHERE t.target_name = 'event_file' and s.name='AlwaysOn_health'); 
IF @tags3 is Not NULL begin WITH cte_HADR AS (SELECT object_name, CONVERT(XML, event_data) AS data FROM sys.fn_xe_file_target_read_file(@tags3, null, null, null)WHERE object_name = 'error_reported')
insert into #errormsg SELECT  data.value('(/event/@timestamp)[1]','datetime')AS [timestamp],data.value('(/event/data[@name=''error_number''])[1]','int') AS [error_number],data.value('(/event/data[@name=''message''])[1]','varchar(max)') AS [message] FROM cte_HADR WHERE data.value('(/event/data[@name=''error_number''])[1]','int') = 1480 select  distinct GETDATE() as currenttime, er.duration,dbs.name  from #errormsg er  inner join sys.databases dbs on er.dbmessage LIKE '%"' +dbs.name+'"%'  where er.duration>=(DATEADD(mi,-30,GETDATE()) );
drop table #errormsg;end 
else IF OBJECT_ID(N'TempDB.dbo.#errormsg', N'U') IS NOT NULL drop table #errormsg;
GO

--#Script#: How to Get WSFC Name Using T-SQL
select * from master.sys.dm_hadr_cluster;
Go

--#Scripts#: To identify previous state of Primary and Secondary on AlwaysON
declare @xel_path varchar(1024);
declare @utc_adjustment int = datediff(hour, getutcdate(), getdate());

-------------------------------------------------------------------------------
------------------- target event_file path retrieval --------------------------
-------------------------------------------------------------------------------
;with target_data_cte as
(
    select  
        target_data = 
            convert(xml, target_data)
    from sys.dm_xe_sessions s
    inner join sys.dm_xe_session_targets st
    on s.address = st.event_session_address
    where s.name = 'alwayson_health'
    and st.target_name = 'event_file'
),
full_path_cte as
(
    select
        full_path = 
            target_data.value('(EventFileTarget/File/@name)[1]', 'varchar(1024)')
    from target_data_cte
)
select
    @xel_path = 
        left(full_path, len(full_path) - charindex('\', reverse(full_path))) + 
        '\AlwaysOn_health*.xel'
from full_path_cte;

-------------------------------------------------------------------------------
------------------- replica state change events -------------------------------
-------------------------------------------------------------------------------
;with state_change_data as
(
    select
        object_name,
        event_data = 
            convert(xml, event_data)
    from sys.fn_xe_file_target_read_file(@xel_path, null, null, null)
)
select
    object_name,
    event_timestamp = 
        dateadd(hour, @utc_adjustment, event_data.value('(event/@timestamp)[1]', 'datetime')),
    ag_name = 
        event_data.value('(event/data[@name = "availability_group_name"]/value)[1]', 'varchar(64)'),
    previous_state = 
        event_data.value('(event/data[@name = "previous_state"]/text)[1]', 'varchar(64)'),
    current_state = 
        event_data.value('(event/data[@name = "current_state"]/text)[1]', 'varchar(64)')
from state_change_data
where object_name = 'availability_replica_state_change'
order by event_timestamp desc;

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

--https://dba.stackexchange.com/questions/76016/how-to-check-history-of-primary-node-in-an-availability-group*/
DECLARE @FileName NVARCHAR(4000)
SELECT @FileName = target_data.value('(EventFileTarget/File/@name)[1]', 'nvarchar(4000)')
    FROM (
           SELECT CAST(target_data AS XML) target_data
            FROM sys.dm_xe_sessions s
            JOIN sys.dm_xe_session_targets t
                ON s.address = t.event_session_address
            WHERE s.name = N'AlwaysOn_health'
         ) ft;

WITH    base
          AS (
               SELECT XEData.value('(event/@timestamp)[1]', 'datetime2(3)') AS event_timestamp
                   ,XEData.value('(event/data/text)[1]', 'VARCHAR(255)') AS previous_state
                   ,XEData.value('(event/data/text)[2]', 'VARCHAR(255)') AS current_state
                   ,ar.replica_server_name
                FROM (
                       SELECT CAST(event_data AS XML) XEData
                           ,*
                        FROM sys.fn_xe_file_target_read_file(@FileName, NULL, NULL, NULL)
                        WHERE object_name = 'availability_replica_state_change'
                     ) event_data
                JOIN sys.availability_replicas ar
                    ON ar.replica_id = XEData.value('(event/data/value)[5]', 'VARCHAR(255)')
             )
    SELECT DATEADD(HOUR, DATEDIFF(HOUR, GETUTCDATE(), GETDATE()), event_timestamp) AS event_timestamp
           ,previous_state
           ,current_state
           ,replica_server_name
        FROM base
        ORDER BY event_timestamp DESC;

--Get cluster Log

Get-ClusterLog -UseLocalTime -TimeSpan 10 -Node node1 -Destination C:\Windows\Cluster\Reports

Troubleshoot:
$dir = "C:\Users\saadmin.NA\Desktop\Cluster-T" 
$files = Get-ChildItem $dir -Recurse -Include "*.log" 
foreach ($file in $files){ 
$out = "ERR_" + $file.BaseName + ".txt" 
select-string -path $file.FullName -Pattern " ERR " -AllMatches | out-file "$dir\$out" 
}


Test-NetConnection -ComputerName "batch42prod" -Port 1433

