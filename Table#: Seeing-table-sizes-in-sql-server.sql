SELECT
    DB_NAME() AS 'DatabaseName'
    ,OBJECT_NAME(p.OBJECT_ID) AS 'TableName'
    ,p.index_id AS 'IndexId'
    ,CASE
        WHEN p.index_id = 0 THEN 'HEAP'
        ELSE i.name
    END AS 'IndexName'
    ,p.partition_number AS 'PartitionNumber'
       ,CASE
        WHEN fg.name IS NULL THEN ds.name
        ELSE fg.name
    END AS 'FileGroupName'
    ,CAST(p.used_page_count * 0.0078125 AS NUMERIC(18,2)) AS 'UsedPages_MB'
    ,CAST(p.in_row_data_page_count * 0.0078125 AS NUMERIC(18,2)) AS 'DataPages_MB'
    ,CAST(p.reserved_page_count * 0.0078125 AS NUMERIC(18,2)) AS 'ReservedPages_MB'
    ,CASE
        WHEN p.index_id IN (0,1) THEN p.ROW_COUNT
        ELSE 0
    END AS 'RowCount'
    ,CASE
        WHEN p.index_id IN (0,1) THEN 'data'
        ELSE 'index'
    END 'Type'
FROM sys.dm_db_partition_stats p
    INNER JOIN sys.indexes i
        ON i.OBJECT_ID = p.OBJECT_ID AND i.index_id = p.index_id
    INNER JOIN sys.data_spaces ds
        ON ds.data_space_id = i.data_space_id
    LEFT OUTER JOIN sys.partition_schemes ps
        ON ps.data_space_id = i.data_space_id
    LEFT OUTER JOIN sys.destination_data_spaces dds
        ON dds.partition_scheme_id = ps.data_space_id
        AND dds.destination_id = p.partition_number
    LEFT OUTER JOIN sys.filegroups fg
        ON fg.data_space_id = dds.data_space_id
    LEFT OUTER JOIN sys.partition_range_values prv_right
        ON prv_right.function_id = ps.function_id
        AND prv_right.boundary_id = p.partition_number
    LEFT OUTER JOIN sys.partition_range_values prv_left
        ON prv_left.function_id = ps.function_id
        AND prv_left.boundary_id = p.partition_number - 1
WHERE
    OBJECTPROPERTY(p.OBJECT_ID, 'ISMSSHipped') = 0
    --AND p.index_id in (0,1)
ORDER BY DataPages_MB DESC

--SCRIPT#2

SELECT t.name AS TableName,
       s.name AS SchemaName,
       p.rows AS RowCounts,
       SUM(a.total_pages) * 8 AS TotalSpaceKB,
       CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
       SUM(a.used_pages) * 8 AS UsedSpaceKB,
       CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB,
       (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,
       CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM sys.tables t
    INNER JOIN sys.indexes i
        ON t.object_id = i.object_id
    INNER JOIN sys.partitions p
        ON i.object_id = p.object_id
           AND i.index_id = p.index_id
    INNER JOIN sys.allocation_units a
        ON p.partition_id = a.container_id
    LEFT OUTER JOIN sys.schemas s
        ON t.schema_id = s.schema_id
WHERE t.name NOT LIKE 'dt%'
      AND t.is_ms_shipped = 0
      AND i.object_id > 255
GROUP BY t.name,
         s.name,
         p.rows
ORDER BY t.name;

--SCRIPT#3
SELECT
    s.Name AS SchemaName,
    t.Name AS TableName,
    p.rows AS NumRows,
    CAST(ROUND((SUM(a.total_pages) / 128.00), 2) AS NUMERIC(36, 2)) AS Total_MB,
    CAST(ROUND((SUM(a.used_pages) / 128.00), 2) AS NUMERIC(36, 2)) AS Used_MB,
    CAST(ROUND((SUM(a.total_pages) - SUM(a.used_pages)) / 128.00, 2) AS NUMERIC(36, 2)) AS Unused_MB
FROM
    sys.tables t
    JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
    JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
    JOIN sys.allocation_units a ON p.partition_id = a.container_id
    LEFT OUTER JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE
    t.name NOT LIKE 'dt%'
    AND t.is_ms_shipped = 0
    AND i.object_id > 255
GROUP BY
    t.Name, s.Name, p.Rows
ORDER BY
    Total_MB DESC, t.Name

