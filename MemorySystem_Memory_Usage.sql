Script to Monitor SQL Server Memory Usage: System Memory Information:
/*********************************************************************/
--Script: Captures System Memory Usage
--Works On: 2008, 2008 R2, 2012, 2014, 2016
/*********************************************************************/

select
      total_physical_memory_kb/1024 AS total_physical_memory_mb,
      available_physical_memory_kb/1024 AS available_physical_memory_mb,
      total_page_file_kb/1024 AS total_page_file_mb,
      available_page_file_kb/1024 AS available_page_file_mb,
      100 - (100 * CAST(available_physical_memory_kb AS DECIMAL(18,3))/CAST(total_physical_memory_kb AS DECIMAL(18,3))) 
      AS 'Percentage_Used',
      system_memory_state_desc
from  sys.dm_os_sys_memory;
