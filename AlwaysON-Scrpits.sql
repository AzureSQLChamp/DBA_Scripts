SELECT ag.name AS ag_name, ar.replica_server_name AS ag_replica_server,
dr_state.database_id as database_id,
is_ag_replica_local = CASE
    WHEN ar_state.is_local = 1 THEN N'LOCAL'
    ELSE 'REMOTE'
    END,
ag_replica_role = CASE
    WHEN ar_state.role_desc IS NULL THEN N'DISCONNECTED'
    ELSE ar_state.role_desc
    END,
dr_state.last_hardened_lsn, dr_state.last_hardened_time,
datediff(s,last_hardened_time, getdate()) as 'seconds behind primary'
FROM (( sys.availability_groups AS ag
JOIN sys.availability_replicas AS ar
    ON ag.group_id = ar.group_id)
JOIN sys.dm_hadr_availability_replica_states AS ar_state
    ON ar.replica_id = ar_state.replica_id)
JOIN sys.dm_hadr_database_replica_states dr_state
    on ag.group_id = dr_state.group_id and dr_state.replica_id = ar_state.replica_id
GO
SELECT ag.name AS ag_name, ar.replica_server_name AS ag_replica_server,
dr_state.database_id as database_id,
is_ag_replica_local = CASE
    WHEN ar_state.is_local = 1 THEN N'LOCAL'
    ELSE 'REMOTE'
    END,
ag_replica_role = CASE
    WHEN ar_state.role_desc IS NULL THEN N'DISCONNECTED'
    ELSE ar_state.role_desc
    END,
ar_state.connected_state_desc, ar.availability_mode_desc, dr_state.synchronization_state_desc
FROM (( sys.availability_groups AS ag
JOIN sys.availability_replicas AS ar
    ON ag.group_id = ar.group_id )
JOIN sys.dm_hadr_availability_replica_states AS ar_state
    ON ar.replica_id = ar_state.replica_id)
JOIN sys.dm_hadr_database_replica_states dr_state
    ON ag.group_id = dr_state.group_id and dr_state.replica_id = ar_state.replica_id
GO
sp_readerrorlog 0,1,'The state of the local availability replica','AAGG1'
GO
select r.replica_server_name, r.endpoint_url,
rs.connected_state_desc, rs.last_connect_error_description, 
rs.last_connect_error_number, rs.last_connect_error_timestamp 
from sys.dm_hadr_availability_replica_states rs join sys.availability_replicas r
on rs.replica_id=r.replica_id
where rs.is_local=1
GO
--CMD MODE:NET HELPMSG 5057
GO
/*IDENTIFYING LOGIN PERMISSIONS ON ALWAYS ON ENDPOINT WITH T-SQL*/
SELECT
    EP.name,
    SP.STATE,
    CONVERT(nvarchar(38), suser_name(SP.grantor_principal_id)) AS GRANTOR,
    SP.TYPE AS PERMISSION,
    CONVERT(nvarchar(46), suser_name(SP.grantee_principal_id)) AS GRANTEE
FROM
    sys.server_permissions SP, sys.endpoints EP
WHERE
    SP.major_id = EP.endpoint_id
ORDER BY
    PERMISSION, GRANTOR, GRANTEE;
GO
USE [msdb]
GO
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
DECLARE @jobId BINARY(16)
EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=N'Run sp_server_diagnostics',
@owner_login_name=N'sa', @job_id = @jobId OUTPUT
/****** Object: Step [Run SP_SERVER_DIAGNOSTICS] Script Date: 2/15/2023 4:20:41 PM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run SP_SERVER_DIAGNOSTICS',
@subsystem=N'TSQL',
@command=N'sp_server_diagnostics 5',
@database_name=N'master',
@output_file_name=N'C:\AAG-Backup\sp_server_diagnostics_output.out',
@flags=2
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
EXEC sp_start_job 'Run sp_server_diagnostics'
