--Seek & Understand Top Indexes by Size in your SQL database
USE [msdb]  /*Replace with your Database Name */
GO
SELECT 
    DB_NAME() DatabaseName,
    OBJECT_SCHEMA_NAME(i.OBJECT_ID) SchemaName,
    OBJECT_NAME(i.OBJECT_ID ) TableName,
    i.name IndexName,
    i.type_desc as [IndexType],
    i.is_primary_key as [PrimaryKeyIndex],
    i.is_unique as [UniqueIndex],
    i.is_disabled as [Disabled],
    SUM(s.used_page_count) / 128.0 IndexSizeinMB,
    CAST((SUM(s.used_page_count)/128.0)/1024.0 as decimal(10,6))  IndexSizeinGB
FROM sys.indexes AS i
INNER JOIN sys.dm_db_partition_stats AS S
    ON i.OBJECT_ID = S.OBJECT_ID AND I.index_id = S.index_id
WHERE i.object_id>99 and i.type_desc='HEAP'
GROUP BY i.OBJECT_ID, i.name, s.used_page_count, i.type_desc, i.is_primary_key, i.is_unique, i.is_disabled
ORDER BY s.used_page_count DESC
GO

