--How can I check the current transaction isolation level?

SELECT CASE transaction_isolation_level
         WHEN 0 THEN 'Unspecified'
         WHEN 1 THEN 'READ UNCOMMITTED'
         WHEN 2 THEN 'READ COMMITTED'
         WHEN 3 THEN 'REPEATABLE READ'
         WHEN 4 THEN 'SERIALIZABLE'
         WHEN 5 THEN 'SNAPSHOT'
       END AS TransactionIsolationLevel
FROM sys.dm_exec_sessions
WHERE session_id = @@SPID;
GO
--============================================ 
--View Locking in Current Database 
--============================================ 
---------------------------------------------------SCRIPT#2------------------------------------------------------------------------
SELECT DTL.resource_type,  
   CASE   
       WHEN DTL.resource_type IN ('DATABASE', 'FILE', 'METADATA') THEN DTL.resource_type  
       WHEN DTL.resource_type = 'OBJECT' THEN OBJECT_NAME(DTL.resource_associated_entity_id, SP.[dbid])  
       WHEN DTL.resource_type IN ('KEY', 'PAGE', 'RID') THEN   
           (  
           SELECT OBJECT_NAME([object_id])  
           FROM sys.partitions  
           WHERE sys.partitions.hobt_id =   
             DTL.resource_associated_entity_id  
           )  
       ELSE 'Unidentified'  
   END AS requested_object_name, DTL.request_mode, DTL.request_status,  
   DEST.TEXT, SP.spid, SP.blocked, SP.status, SP.loginame 
FROM sys.dm_tran_locks DTL  
   INNER JOIN sys.sysprocesses SP  
       ON DTL.request_session_id = SP.spid   
   --INNER JOIN sys.[dm_exec_requests] AS SDER ON SP.[spid] = [SDER].[session_id] 
   CROSS APPLY sys.dm_exec_sql_text(SP.sql_handle) AS DEST  
WHERE SP.dbid = DB_ID()  
   AND DTL.[resource_type] <> 'DATABASE' 
ORDER BY DTL.[request_session_id];
GO
---------------------------------------------------SCRIPT#2------------------------------------------------------------------------
SELECT dm_tran_locks.request_session_id,  
       dm_tran_locks.resource_database_id,  
       DB_NAME(dm_tran_locks.resource_database_id) AS dbname,  
       CASE  
           WHEN resource_type = 'OBJECT'  
               THEN OBJECT_NAME(dm_tran_locks.resource_associated_entity_id)  
           ELSE OBJECT_NAME(partitions.OBJECT_ID)  
       END AS ObjectName,  
       partitions.index_id,  
       indexes.name AS index_name,  
       dm_tran_locks.resource_type,  
       dm_tran_locks.resource_description,  
       dm_tran_locks.resource_associated_entity_id,  
       dm_tran_locks.request_mode,  
       dm_tran_locks.request_status  
FROM sys.dm_tran_locks  
LEFT JOIN sys.partitions ON partitions.hobt_id = dm_tran_locks.resource_associated_entity_id  
LEFT JOIN sys.indexes ON indexes.OBJECT_ID = partitions.OBJECT_ID AND indexes.index_id = partitions.index_id  
WHERE resource_associated_entity_id > 0  
  AND resource_database_id = DB_ID()  
 and request_session_id= <>                           --Pass Session ID 
ORDER BY request_session_id, resource_associated_entity_id
GO
---------------------------------------------------SCRIPT#3------------------------------------------------------------------------
select
   obj.name                          object_name,
   obj.type_desc,
   obj.schema_id,
   db.name                           db_names,
   trx_lock.request_status,
   trx_lock.request_reference_count,
   trx_lock.request_session_id,
   wait.blocking_session_id,
   wait.resource_description,
   object_name(parts.object_id)      blocked_object,   -- ?
   trx_lock.resource_type,
   sql_request.text                  sql_text_request,
   sql_blocked.text                  sql_text_blocked,
   trx_lock.request_mode
from
   sys.dm_tran_locks       trx_lock                                                                                       join
   sys.databases           db          on db.database_id                          = trx_lock.resource_database_id   left  join
   sys.dm_os_waiting_tasks wait        on trx_lock.lock_owner_address             = wait.resource_address           left  join
   sys.partitions          parts       on trx_lock.resource_associated_entity_id  = parts.hobt_id                   left  join
   sys.dm_exec_connections ses_request on ses_request.session_id                  = trx_lock.request_session_id     left  join
   sys.dm_exec_connections ses_blocked on ses_blocked.session_id                  = wait.blocking_session_id        left  join
   sys.all_objects         obj         on trx_lock.resource_associated_entity_id  = obj.object_id                   outer apply
   sys.dm_exec_sql_text(ses_request.most_recent_sql_handle)                         sql_request                     outer apply
   sys.dm_exec_sql_text(ses_blocked.most_recent_sql_handle)                         sql_blocked
WHERE db.name = <>   --Database Name
