--Script # – INDEXES WITH MORE WRITES THAN READS
USE [DBNAME] /* Replace with your Database Name */
GO
--INDEXES WITH WRITES > READS
SELECT DB_NAME(s.database_id) as [DB Name], OBJECT_NAME(s.[object_id]) AS [Table Name], i.name AS [Index Name], i.index_id,
    i.is_disabled, i.is_hypothetical, i.has_filter, i.fill_factor, i.is_unique,
    s.user_updates AS [Total Writes],
    (s.user_seeks + s.user_scans + s.user_lookups) AS [Total Reads],
    s.user_updates - (s.user_seeks + s.user_scans + s.user_lookups) AS [Difference],
    (partstats.used_page_count / 128.0) AS [IndexSizeinMB]
FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
INNER JOIN sys.indexes AS i WITH (NOLOCK)
    ON s.[object_id] = i.[object_id]
    AND s.index_id = i.index_id
    AND s.database_id = DB_ID()
INNER JOIN sys.dm_db_partition_stats AS partstats
    ON i.object_id = partstats.object_id AND i.index_id = partstats.index_id
WHERE OBJECTPROPERTY(s.[object_id],'IsUserTable') = 1
    AND (s.user_lookups<>0 OR s.user_scans<>0 OR s.user_seeks<>0)
    AND s.user_updates > (s.user_seeks + s.user_scans + s.user_lookups)
    AND i.index_id > 1
ORDER BY [Difference] DESC, [Total Writes] DESC, [Total Reads] ASC OPTION (RECOMPILE);
GO

