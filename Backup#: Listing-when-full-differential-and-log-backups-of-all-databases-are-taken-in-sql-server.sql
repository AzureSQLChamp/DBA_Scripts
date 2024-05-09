SELECT
	substring(s.name, 1, 50) AS 'DatabaseName'
   ,b.backup_start_date AS 'Full DB Backup'
   ,c.backup_start_date AS 'Differential Backup'
   ,d.backup_start_date AS 'Transaction Log backup'
FROM master..sysdatabases s
LEFT OUTER JOIN msdb..backupset b
	ON s.name = b.database_name
		AND b.backup_start_date = (SELECT
				MAX(backup_start_date) AS 'Full DB Backup'
			FROM msdb..backupset
			WHERE database_name = b.database_name
			AND b.TYPE = 'D') -- full database backups only, not log backups
LEFT OUTER JOIN msdb..backupset c
	ON s.name = c.database_name
		AND c.backup_start_date = (SELECT
				MAX(backup_start_date) 'Differential Backup'
			FROM msdb..backupset
			WHERE database_name = c.database_name
			AND b.TYPE = 'I')
LEFT OUTER JOIN msdb..backupset d
	ON s.name = d.database_name
		AND d.backup_start_date = (SELECT
				MAX(backup_start_date) 'Log Backup'
			FROM msdb..backupset
			WHERE database_name = d.database_name
			AND b.TYPE = 'L')
WHERE s.name <> 'tempdb'
ORDER BY s.name


	

--Databases with data backup over 24 hours old 
SELECT 
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server, 
   msdb.dbo.backupset.database_name, 
   MAX(msdb.dbo.backupset.backup_finish_date) AS last_db_backup_date, 
   DATEDIFF(hh, MAX(msdb.dbo.backupset.backup_finish_date), GETDATE()) AS [Backup Age (Hours)] 
FROM 
   msdb.dbo.backupset 
WHERE 
   msdb.dbo.backupset.type = 'L'  
GROUP BY 
   msdb.dbo.backupset.database_name 
HAVING 
   (MAX(msdb.dbo.backupset.backup_finish_date) < DATEADD(hh, - 24, GETDATE()))  

UNION  

--Databases without any backup history 
SELECT      
   CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,  
   master.sys.sysdatabases.NAME AS database_name,  
   NULL AS [Last Data Backup Date],  
   9999 AS [Backup Age (Hours)]  
FROM 
   master.sys.sysdatabases 
   LEFT JOIN msdb.dbo.backupset ON master.sys.sysdatabases.name = msdb.dbo.backupset.database_name 
WHERE 
   msdb.dbo.backupset.database_name IS NULL 
   AND master.sys.sysdatabases.name <> 'tempdb' 
ORDER BY  
   msdb.dbo.backupset.database_name



SELECT 
CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,
msdb.dbo.backupset.database_name, 
msdb.dbo.backupset.backup_start_date, 
msdb.dbo.backupset.backup_finish_date,
msdb.dbo.backupset.expiration_date,
msdb.dbo.backupset.user_name,
msdb.dbo.backupset.checkpoint_lsn,
msdb.dbo.backupset.is_copy_only,
CAST( msdb.dbo.backupset.first_lsn AS VARCHAR(50)) AS first_lsn
,CAST(msdb.dbo.backupset.last_lsn AS VARCHAR(50)) AS last_lsn,
CASE msdb..backupset.type 
WHEN 'D' THEN 'Database' 
WHEN 'L' THEN 'Log' 
when 'I' THEN 'Differential database '
END AS backup_type, 
msdb.dbo.backupset.backup_size, 
convert(decimal(18, 2), msdb.dbo.backupset.backup_size / 1024 / 1024 / 1024) as BackupSizeGB,
msdb.dbo.backupmediafamily.logical_device_name, 
msdb.dbo.backupmediafamily.physical_device_name, 
msdb.dbo.backupset.name AS backupset_name,
msdb.dbo.backupset.is_copy_only,
msdb.dbo.backupset.description
FROM msdb.dbo.backupmediafamily 
INNER JOIN msdb.dbo.backupset ON msdb.dbo.backupmediafamily.media_set_id = msdb.dbo.backupset.media_set_id 
WHERE (CONVERT(datetime, msdb.dbo.backupset.backup_start_date, 102) >= GETDATE() - 1) 
--AND msdb.dbo.backupset.database_name = '<DBNAME>'
AND msdb..backupset.type IN ('D','I','L')
ORDER BY 
msdb.dbo.backupset.backup_finish_date DESC

--Size of the log backups
select A.database_name,A.backup_start_date,
A.backup_finish_date,A.type,B.physical_device_name--((A.backup_size)/(1024*1024*1024)) as backup_size_GB,((A.compressed_backup_size)/(1024*1024*1024)) as Comp_Size_GB
from msdb..backupset A, msdb..backupmediafamily B
where A.media_set_id = B.media_set_id and a.type='L'
order by A.backup_finish_date desc
