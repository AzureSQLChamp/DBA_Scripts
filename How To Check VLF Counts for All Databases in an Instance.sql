--How can I tell how many logs VLF’s I have?
--Either of these 2 scripts should give you the information;

DBCC LOGINFO(<DatabaseName>)

--SQL SERVER – Query to List Active and Inactive VLF
SELECT [name], s.database_id,
COUNT(l.database_id) AS ‘VLF Count’,
SUM(vlf_size_mb) AS ‘VLF Size (MB)’,
SUM(CAST(vlf_active AS INT)) AS ‘Active VLF’,
SUM(vlf_activevlf_size_mb) AS ‘Active VLF Size (MB)’, COUNT(l.database_id)-SUM(CAST(vlf_active AS INT)) AS ‘In-active VLF’, SUM(vlf_size_mb)-SUM(vlf_activevlf_size_mb) AS ‘In-active VLF Size (MB)’
FROM sys.databases s
CROSS APPLY sys.dm_db_log_info(s.database_id) l
GROUP BY [name], s.database_id
ORDER BY ‘VLF Count’ DESC
GO

CREATE TABLE #VLFInfo
(
    RecoveryUnitID INT
    ,FileID INT
    ,FileSize BIGINT
    ,StartOffset BIGINT
    ,FSeqNo BIGINT
    ,Status BIGINT
    ,Parity BIGINT
    ,CreateLSN NUMERIC(38)
);

CREATE TABLE #VLFCountResults
(
    DatabaseName sysname
    ,VLFCount INT
)
    
EXEC sp_MSforeachdb N'Use [?];

        INSERT INTO #VLFInfo
        EXEC sp_executesql N''DBCC LOGINFO([?])'';

        INSERT INTO #VLFCountResults
        SELECT DB_NAME(), COUNT(*)
        FROM #VLFInfo;

        TRUNCATE TABLE #VLFInfo;'

SELECT 
    DatabaseName
    ,VLFCount
FROM 
    #VLFCountResults
ORDER BY 
    VLFCount DESC

DROP TABLE #VLFInfo
DROP TABLE #VLFCountResults

-- High VLF counts can affect write performance
-- and they can make database restored and recovery take much longer
