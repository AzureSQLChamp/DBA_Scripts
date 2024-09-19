SELECT DISTINCT 
    t.name AS TableName,
    i.name AS IndexName,
    (CASE 
        WHEN i.type_desc IN ('HEAP', 'CLUSTERED') THEN 'DATA'
        WHEN i.type_desc = 'NONCLUSTERED' THEN 'INDEX'
        ELSE i.type_desc 
    END) AS Type,
    fg.name AS FileGroupName,
    f.name AS FileName,
    LEFT(f.physical_name, 1) AS FileDirectory,
    f.physical_name AS FilePath,
    CAST((SUM(ps.used_page_count) * 8.0 / 1024) AS DECIMAL(10, 2)) AS TableSizeMB,
    CAST((SUM(CASE WHEN i.type_desc IN ('HEAP', 'CLUSTERED') THEN ps.used_page_count ELSE 0 END) * 8.0 / 1024) AS DECIMAL(10, 2)) AS IndexSizeMB
FROM 
    sys.indexes i
INNER JOIN 
    sys.tables t ON t.object_id = i.object_id
INNER JOIN 
    sys.filegroups fg ON i.data_space_id = fg.data_space_id
INNER JOIN 
    sys.database_files f ON f.data_space_id = fg.data_space_id
INNER JOIN 
    sys.dm_db_partition_stats ps ON ps.object_id = t.object_id
GROUP BY 
    t.name, i.name, i.type_desc, fg.name, f.name, f.physical_name
ORDER BY 
    t.name, i.name;
