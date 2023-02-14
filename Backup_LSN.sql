SELECT
    database_name
   ,type = ( CASE type
            when 'D' then 'FULL DB BACKUP'
            when 'I' then 'DIFFERENTIAL Backup'
            when 'L' then 'Log Backup'
            END)
   ,checkpoint_lsn
   ,database_backup_lsn
   ,differential_base_lsn
   ,backup_start_date
FROM msdb.dbo.backupset
WHERE backup_start_date>'2018-09-02 11:12:00.000' -- Optional, you can give a suitable time

