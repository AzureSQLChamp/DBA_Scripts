/*==============================================================
  Always On Availability Group - Failover Readiness Check
  Author  : DBA
  Purpose : Verify if the secondary replica is ready for failover
==============================================================*/

SET NOCOUNT ON;

SELECT
    AG.name AS [AG Name],
    AR.replica_server_name AS [Replica Server],
    ARS.role_desc AS [Replica Role],
    ARS.connected_state_desc AS [Connection Status],
    AR.availability_mode_desc AS [Availability Mode],
    AR.failover_mode_desc AS [Failover Mode],

    DB_NAME(DRS.database_id) AS [Database Name],

    DRS.synchronization_state_desc AS [Sync State],
    DRS.synchronization_health_desc AS [Sync Health],
    DRS.is_suspended AS [Is Suspended],
    DRS.is_primary_replica AS [Is Primary],

    DRCS.is_failover_ready AS [Failover Ready],

    DRS.log_send_queue_size AS [Log Send Queue (KB)],
    DRS.redo_queue_size AS [Redo Queue (KB)],
    DRS.redo_rate AS [Redo Rate (KB/sec)],
    DRS.log_send_rate AS [Log Send Rate (KB/sec)],

    CASE
        WHEN DRCS.is_failover_ready = 1
         AND DRS.synchronization_state_desc = 'SYNCHRONIZED'
         AND DRS.synchronization_health_desc = 'HEALTHY'
         AND DRS.is_suspended = 0
         AND ARS.connected_state_desc = 'CONNECTED'
         THEN '✅ READY FOR PLANNED FAILOVER'

        WHEN DRS.is_suspended = 1
         THEN '❌ Database Suspended'

        WHEN ARS.connected_state_desc <> 'CONNECTED'
         THEN '❌ Replica Disconnected'

        WHEN DRS.synchronization_state_desc <> 'SYNCHRONIZED'
         THEN '❌ Database Not Synchronized'

        WHEN DRS.synchronization_health_desc <> 'HEALTHY'
         THEN '❌ Synchronization Not Healthy'

        ELSE '⚠ Review Replica Status'
    END AS [Failover Status]

FROM sys.availability_groups AG
JOIN sys.availability_replicas AR
    ON AG.group_id = AR.group_id
JOIN sys.dm_hadr_availability_replica_states ARS
    ON AR.replica_id = ARS.replica_id
JOIN sys.dm_hadr_database_replica_states DRS
    ON AR.replica_id = DRS.replica_id
LEFT JOIN sys.dm_hadr_database_replica_cluster_states DRCS
    ON DRS.group_database_id = DRCS.group_database_id
   AND DRS.replica_id = DRCS.replica_id

ORDER BY
    AG.name,
    AR.replica_server_name,
    [Database Name];
