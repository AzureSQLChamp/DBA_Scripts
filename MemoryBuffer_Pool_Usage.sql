select * from sys.dm_os_nodes   --OS level memory nodes

select * from sys.dm_os_memory_nodes  --SQL level memory nodes

select * from sys.dm_os_memory_clerks  --Clerk details 

--Get Buffer pool from clerk:

SELECT TOP(5) [type] AS [ClerkType],
SUM(pages_kb) / 1024 AS [SizeMb]
FROM sys.dm_os_memory_clerks WITH (NOLOCK)
GROUP BY [type]
ORDER BY SUM(pages_kb) DESC

select * from sys.dm_os_memory_clerks  ORDER BY pages_kb DESC

