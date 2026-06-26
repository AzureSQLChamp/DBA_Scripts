/******************************************************************************
    SQL Server Always On Availability Group Health Check
    Purpose : Verify AG Health and Planned Failover Readiness
******************************************************************************/

SET NOCOUNT ON;

;WITH ReplicaInfo AS
(
    SELECT
        ag.group_id,
        ag.name AS AGName,
        MAX(CASE WHEN ars.role_desc = 'PRIMARY'
                 THEN ar.replica_server_name END) AS PrimaryReplica,
        STRING_AGG(CASE WHEN ars.role_desc = 'SECONDARY'
                        THEN ar.replica_server_name END, ', ')
            AS SecondaryReplicas
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar
        ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states ars
        ON ar.replica_id = ars.replica_id
    GROUP BY ag.group_id, ag.name
)

SELECT

    RI.AGName                                    AS [AG Name],
    RI.PrimaryReplica                            AS [Current Primary Replica],
    RI.SecondaryReplicas                         AS [Current Secondary Replica(s)],

    AR.replica_server_name                       AS [Replica Name],
    ARS.role_desc                                AS [Replica Role],
    ARS.connected_state_desc                     AS [Connection Status],

    ADC.database_name                            AS [Database Name],
    DRS.database_state_desc                      AS [Database State],

    AR.availability_mode_desc                    AS [Availability Mode],
    AR.failover_mode_desc                        AS [Failover Mode],

    DRS.synchronization_state_desc               AS [Synchronization State],
    DRS.synchronization_health_desc              AS [Synchronization Health],

    DRS.is_primary_replica                       AS [Is Primary Replica],
    DRS.is_suspended                             AS [Is Suspended],
    DRCS.is_failover_ready                       AS [Is Failover Ready],

    DRS.log_send_queue_size                      AS [Log Send Queue (KB)],
    DRS.redo_queue_size                          AS [Redo Queue (KB)],

    DRS.log_send_rate                            AS [Log Send Rate (KB/sec)],
    DRS.redo_rate                                AS [Redo Rate (KB/sec)],

    CASE

        WHEN DRCS.is_failover_ready = 1
         AND DRS.synchronization_state_desc='SYNCHRONIZED'
         AND DRS.synchronization_health_desc='HEALTHY'
         AND DRS.database_state_desc='ONLINE'
         AND DRS.is_suspended=0
         AND ARS.connected_state_desc='CONNECTED'

        THEN 'READY FOR PLANNED FAILOVER'

        WHEN DRS.is_suspended=1
        THEN 'Database Suspended'

        WHEN ARS.connected_state_desc<>'CONNECTED'
        THEN 'Replica Disconnected'

        WHEN DRS.database_state_desc<>'ONLINE'
        THEN 'Database Offline'

        WHEN DRS.synchronization_state_desc<>'SYNCHRONIZED'
        THEN 'Database Not Synchronized'

        WHEN DRS.synchronization_health_desc<>'HEALTHY'
        THEN 'Synchronization Not Healthy'

        ELSE 'Review Replica'

    END AS [Failover Status]

FROM ReplicaInfo RI

JOIN sys.availability_groups AG
    ON RI.group_id = AG.group_id

JOIN sys.availability_replicas AR
    ON AG.group_id = AR.group_id

JOIN sys.dm_hadr_availability_replica_states ARS
    ON AR.replica_id = ARS.replica_id

JOIN sys.dm_hadr_database_replica_states DRS
    ON AR.replica_id = DRS.replica_id

JOIN sys.availability_databases_cluster ADC
    ON DRS.group_database_id = ADC.group_database_id

LEFT JOIN sys.dm_hadr_database_replica_cluster_states DRCS
    ON DRS.group_database_id = DRCS.group_database_id
   AND DRS.replica_id = DRCS.replica_id

ORDER BY
    RI.AGName,
    ADC.database_name,
    ARS.role_desc DESC;
