--IO issue:
select [database_id],
DB_name([database_id]) as [Database_name],
[FILE_ID],
[num_of_reads],
[io_stall_read_ms],
[io_stall_read_ms]/[num_of_reads] as Avg_Read_Latency_MS,
[num_of_bytes_read],
[num_of_writes],
[num_of_bytes_written],
[io_stall_write_ms],
[io_stall],
[size_on_disk_bytes]
 from sys.[dm_io_virtual_file_stats](NULL,NULL)
 ORDER BY [io_stall] DESC

--Note:/*
•	Io_stall_read_ms : total time in ms read request have is wait.
•	As per Microsoft recommended Read latency more that 20ms we need to troubleshoot.
•	Data file latency: <= 20 ms (OLTP) <=30 ms (DW),  Log files: <= 5 ms
*/
