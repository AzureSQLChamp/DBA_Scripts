SELECT
	substring(s.name, 1, 50) AS 'Veritabanı_Adi'
   ,b.backup_start_date AS 'Full DB Backup Tarihi'
   ,c.backup_start_date AS 'Differential Backup Tarihi'
   ,d.backup_start_date AS 'Transaction Log Tarihi'
FROM master..sysdatabases s
LEFT OUTER JOIN msdb..backupset b
	ON s.name = b.database_name
		AND b.backup_start_date = (SELECT
				MAX(backup_start_date) AS 'Full DB Backup Tarihi'
			FROM msdb..backupset
			WHERE database_name = b.database_name
			AND TYPE = 'D') -- full database backups only, not log backups
LEFT OUTER JOIN msdb..backupset c
	ON s.name = c.database_name
		AND c.backup_start_date = (SELECT
				MAX(backup_start_date) 'Differential Backup Tarihi'
			FROM msdb..backupset
			WHERE database_name = c.database_name
			AND TYPE = 'I')
LEFT OUTER JOIN msdb..backupset d
	ON s.name = d.database_name
		AND d.backup_start_date = (SELECT
				MAX(backup_start_date) 'Log Backup Tarihi'
			FROM msdb..backupset
			WHERE database_name = d.database_name
			AND TYPE = 'L')
WHERE s.name <> 'tempdb'
ORDER BY s.name

