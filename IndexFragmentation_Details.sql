--Check SQL Server a specified database index fragmentation percentage (SQL)
SELECT
    DB_NAME() AS DatabaseName, -- Retrieve the current database name
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName, -- Retrieve the schema name of the object
    OBJECT_NAME(i.object_id) AS TableName, -- Retrieve the table name of the object
    i.name AS IndexName, -- Retrieve the name of the index
    CASE
        WHEN i.type = 1 THEN 'Clustered' -- Determine the index type
        WHEN i.type = 2 THEN 'Nonclustered'
        WHEN i.type = 3 THEN 'XML'
        WHEN i.type = 4 THEN 'Spatial'
        WHEN i.type = 5 THEN 'Clustered Columnstore'
        WHEN i.type = 6 THEN 'Nonclustered Columnstore'
        WHEN i.type = 7 THEN 'Nonclustered Hash'
        ELSE 'Unknown'
    END AS IndexType,
    o.create_date AS CreationDate, -- Retrieve the creation date of the index
    COALESCE(us.last_user_seek, us.last_user_scan, us.last_user_lookup) AS LastUsedDate, -- Retrieve the last used date of the index
    us.last_user_update AS LastRebuildDate, -- Retrieve the last rebuild date of the index
    ps.avg_fragmentation_in_percent AS FragmentationPercentage, -- Retrieve the fragmentation percentage of the index
    CASE
        WHEN ps.avg_fragmentation_in_percent > 40 THEN 'Rebuild Index' -- Check if the fragmentation percentage is greater than 40%
        ELSE 'Rebuild Index Not Required'
    END AS RebuildStatus, -- Display the rebuild status based on the fragmentation percentage
    CASE
        WHEN ps.avg_fragmentation_in_percent > 40 THEN 'ALTER INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id)) + '.' + QUOTENAME(OBJECT_NAME(i.object_id)) + ' REBUILD'
        ELSE ''
    END AS RebuildScript -- Suggest the T-SQL script to rebuild the index if applicable
FROM
    sys.indexes AS i
JOIN sys.objects AS o ON i.object_id = o.object_id
LEFT JOIN sys.dm_db_index_usage_stats AS us ON i.object_id = us.object_id AND i.index_id = us.index_id
OUTER APPLY sys.dm_db_index_physical_stats(DB_ID(), i.object_id, i.index_id, NULL, 'LIMITED') AS ps
WHERE
    i.index_id > 0
    AND i.object_id > 0;

--sp_helpdb

DECLARE @dbid int = 5
 
SELECT  dbschemas.[name] as 'Schema',
        dbtables.[name] as 'Table',
        dbindexes.[name] as 'Index',
        indexstats.avg_fragmentation_in_percent,
        indexstats.page_count,
        indexstats.forwarded_record_count,
        CASE WHEN indexstats.page_count <= 1000 OR indexstats.avg_fragmentation_in_percent < 10 THEN '--Do nothing. It''s good'
             WHEN indexstats.avg_fragmentation_in_percent BETWEEN 10 AND 40 THEN 'ALTER INDEX '+dbindexes.[name]+' ON '+dbschemas.[name]+'.'+dbtables.[name]+' REORGANIZE;'
             ELSE 'ALTER INDEX '+dbindexes.[name]+' ON '+dbschemas.[name]+'.'+dbtables.[name]+' REBUILD;'
        END
FROM    sys.dm_db_index_physical_stats (@dbid, NULL, NULL, NULL, NULL) AS indexstats
JOIN    sys.tables dbtables ON dbtables.[object_id] = indexstats.[object_id]
JOIN    sys.schemas dbschemas ON dbtables.[schema_id] = dbschemas.[schema_id]
JOIN    sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id] AND indexstats.index_id = dbindexes.index_id
WHERE   indexstats.database_id = @dbid
ORDER BY indexstats.avg_fragmentation_in_percent DESC

