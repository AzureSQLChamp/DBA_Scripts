--#Script1
;WITH AG_Stats AS (
            SELECT AGS.name                       AS AGGroupName, 
                   AR.replica_server_name         AS InstanceName, 
                   HARS.role_desc, 
                   Db_name(DRS.database_id)       AS DBName, 
                   DRS.database_id, 
                   AR.availability_mode_desc      AS SyncMode, 
                   DRS.synchronization_state_desc AS SyncState, 
                   DRS.last_hardened_lsn, 
                   DRS.end_of_log_lsn, 
                   DRS.last_redone_lsn, 
                   DRS.last_hardened_time, -- On a secondary database, time of the log-block identifier for the last hardened LSN (last_hardened_lsn).
                   DRS.last_redone_time, -- Time when the last log record was redone on the secondary database.
                   DRS.log_send_queue_size, 
                   DRS.redo_queue_size,
                    --Time corresponding to the last commit record.
                    --On the secondary database, this time is the same as on the primary database.
                    --On the primary replica, each secondary database row displays the time that the secondary replica that hosts that secondary database 
                    --   has reported back to the primary replica. The difference in time between the primary-database row and a given secondary-database 
                    --   row represents approximately the recovery time objective (RPO), assuming that the redo process is caught up and that the progress 
                    --   has been reported back to the primary replica by the secondary replica.
                   DRS.last_commit_time
            FROM   sys.dm_hadr_database_replica_states DRS 
            LEFT JOIN sys.availability_replicas AR 
            ON DRS.replica_id = AR.replica_id 
            LEFT JOIN sys.availability_groups AGS 
            ON AR.group_id = AGS.group_id 
            LEFT JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id 
            AND AR.replica_id = HARS.replica_id 
            ),
    Pri_CommitTime AS 
            (
            SELECT  DBName
                    , last_commit_time
            FROM    AG_Stats
            WHERE   role_desc = 'PRIMARY'
            ),
    Rpt_CommitTime AS 
            (
            SELECT  DBName, last_commit_time
            FROM    AG_Stats
            WHERE   role_desc = 'SECONDARY' AND [InstanceName] = 'InstanceNameB-PrimaryDataCenter'
            ),
    FO_CommitTime AS 
            (
            SELECT  DBName, last_commit_time
            FROM    AG_Stats
            WHERE   role_desc = 'SECONDARY' AND ([InstanceName] = 'InstanceNameC-SecondaryDataCenter' OR [InstanceName] = 'InstanceNameD-SecondaryDataCenter')
            )
SELECT p.[DBName] AS [DatabaseName], p.last_commit_time AS [Primary_Last_Commit_Time]
    , r.last_commit_time AS [Reporting_Last_Commit_Time]
    , DATEDIFF(ss,r.last_commit_time,p.last_commit_time) AS [Reporting_Sync_Lag_(secs)]
    , f.last_commit_time AS [FailOver_Last_Commit_Time]
    , DATEDIFF(ss,f.last_commit_time,p.last_commit_time) AS [FailOver_Sync_Lag_(secs)]
FROM Pri_CommitTime p
LEFT JOIN Rpt_CommitTime r ON [r].[DBName] = [p].[DBName]
LEFT JOIN FO_CommitTime f ON [f].[DBName] = [p].[DBName]

--#Script2
SELECT 
	ar.replica_server_name, 
	adc.database_name, 
	ag.name AS ag_name, 
	drs.is_local, 
	drs.is_primary_replica, 
	drs.synchronization_state_desc, 
	drs.is_commit_participant, 
	drs.synchronization_health_desc, 
	drs.recovery_lsn, 
	drs.truncation_lsn, 
	drs.last_sent_lsn, 
	drs.last_sent_time, 
	drs.last_received_lsn, 
	drs.last_received_time, 
	drs.last_hardened_lsn, 
	drs.last_hardened_time, 
	drs.last_redone_lsn, 
	drs.last_redone_time, 
	drs.log_send_queue_size, 
	drs.log_send_rate, 
	drs.redo_queue_size, 
	drs.redo_rate, 
	drs.filestream_send_rate, 
	drs.end_of_log_lsn, 
	drs.last_commit_lsn, 
	drs.last_commit_time
FROM sys.dm_hadr_database_replica_states AS drs
INNER JOIN sys.availability_databases_cluster AS adc 
	ON drs.group_id = adc.group_id AND 
	drs.group_database_id = adc.group_database_id
INNER JOIN sys.availability_groups AS ag
	ON ag.group_id = drs.group_id
INNER JOIN sys.availability_replicas AS ar 
	ON drs.group_id = ar.group_id AND 
	drs.replica_id = ar.replica_id
ORDER BY 
	ag.name, 
	ar.replica_server_name, 
	adc.database_name;
