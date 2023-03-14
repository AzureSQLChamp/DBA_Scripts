DECLARE @newDriveAndFolder VARCHAR(8000);

SET @newDriveAndFolder = 'Z:\YourTempDBfolder';

SELECT [name] AS [Logical Name]
    ,physical_name AS [Current Location]
    ,state_desc AS [Status]
    ,size / 128 AS [Size(MB)] --Number of 8KB pages / 128 = MB
    ,'ALTER DATABASE tempdb MODIFY FILE (NAME = ' + QUOTENAME(f.[name])
    + CHAR(9) /* Tab */
    + ',FILENAME = ''' + @newDriveAndFolder + CHAR(92) /* Backslash */ + f.[name]
    + CASE WHEN f.[type] = 1 /* Log */ THEN '.ldf' ELSE '.mdf' END  + ''''
    + ');'
    AS [Create new TempDB files]
FROM sys.master_files f
WHERE f.database_id = DB_ID(N'tempdb')
ORDER BY f.[type];
