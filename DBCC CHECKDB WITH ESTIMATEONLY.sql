-- Assumes you are testing against a smaller database and extrapolating to 1TB

-- Step 1: Initialize variables
DECLARE @read_before BIGINT, @write_before BIGINT
DECLARE @read_after BIGINT, @write_after BIGINT
DECLARE @tempdb_read_MB FLOAT, @tempdb_write_MB FLOAT
DECLARE @internal_MB FLOAT, @total_MB FLOAT
DECLARE @db_name SYSNAME = 'StackOverflow2013'  -- Replace with your database name
DECLARE @db_size_GB FLOAT = 100.0        -- Actual DB size used for test (in GB)
DECLARE @target_db_size_GB FLOAT = 1024.0  -- Size to estimate against (e.g., 1TB)

-- Step 2: Capture tempdb I/O before CHECKDB
SELECT  
    @read_before = SUM(fs.num_of_bytes_read),
    @write_before = SUM(fs.num_of_bytes_written)
FROM tempdb.sys.database_files AS df
JOIN sys.dm_io_virtual_file_stats(2, NULL) AS fs
    ON fs.file_id = df.file_id
WHERE df.type = 0;

-- Step 3: Run CHECKDB
DBCC CHECKDB(@db_name) WITH NO_INFOMSGS;

-- Step 4: Capture tempdb I/O after CHECKDB
SELECT  
    @read_after = SUM(fs.num_of_bytes_read),
    @write_after = SUM(fs.num_of_bytes_written)
FROM tempdb.sys.database_files AS df
JOIN sys.dm_io_virtual_file_stats(2, NULL) AS fs
    ON fs.file_id = df.file_id
WHERE df.type = 0;

-- Step 5: Calculate actual tempdb usage in MB
SET @tempdb_read_MB = (@read_after - @read_before) / 1024.0 / 1024.0;
SET @tempdb_write_MB = (@write_after - @write_before) / 1024.0 / 1024.0;

-- Step 6: Get internal object allocation size
SELECT @internal_MB = internal_objects_alloc_page_count * 8.0 / 1024.0
FROM sys.dm_db_task_space_usage
WHERE session_id = @@SPID;

-- Step 7: Total tempdb usage for current CHECKDB
SET @total_MB = @tempdb_read_MB + @tempdb_write_MB + ISNULL(@internal_MB, 0);

-- Step 8: Extrapolate to 1TB (or target size)
DECLARE @scaling_factor FLOAT = @target_db_size_GB / @db_size_GB;
DECLARE @estimated_tempdb_MB FLOAT = @total_MB * @scaling_factor;

-- Step 9: Output results
SELECT 
    @tempdb_read_MB AS Actual_Read_MB,
    @tempdb_write_MB AS Actual_Write_MB,
    @internal_MB AS Internal_Alloc_MB,
    @total_MB AS Total_Tempdb_Used_MB,
    @scaling_factor AS Scaling_Factor,
    @estimated_tempdb_MB AS Estimated_Tempdb_MB_for_Target_Size,
    @estimated_tempdb_MB / 1024.0 AS Estimated_Tempdb_GB_for_Target_Size;


Ref: https://amihalj.wordpress.com/2011/11/11/dbcc-checkdb-with-estimateonly-do-you-trust-it/
