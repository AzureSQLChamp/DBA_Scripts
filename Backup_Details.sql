-- Get Backup History for required database
SELECT 
s.database_name,
m.physical_device_name,
CAST(CAST(s.backup_size / 1048576 AS INT) AS VARCHAR(14))  AS bkSizeMB,
CAST(CAST(s.compressed_backup_size / 1048576 AS INT) AS VARCHAR(14))  AS Compressed_bkSizeMB,
CAST(DATEDIFF(second, s.backup_start_date,
s.backup_finish_date) AS VARCHAR(12)) + ' ' + 'Seconds' TimeTaken,
s.backup_start_date,
CAST(s.first_lsn AS VARCHAR(50)) AS first_lsn,
CAST(s.last_lsn AS VARCHAR(50)) AS last_lsn,
CASE s.[type]
WHEN 'D' THEN 'Full'
WHEN 'I' THEN 'Differential'
WHEN 'L' THEN 'Transaction Log'
END AS BackupType,
s.server_name,
s.recovery_model
FROM msdb.dbo.backupset s
INNER JOIN msdb.dbo.backupmediafamily m ON s.media_set_id = m.media_set_id
WHERE s.backup_start_date>'2017-04-01'  --adjust your date
--Uncomment below lines if you want a one or more type of backup
--AND (s.type='D' OR s.type ='I')
--AND (s.type='L' )
--Uncomment below line if you want to filter by database name
--AND database_name ='security'
ORDER BY backup_start_date DESC, backup_finish_date



