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


