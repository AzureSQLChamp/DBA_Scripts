--To get Database Name 

SELECT * FROM sys.databases WHERE database_ID in (5)
GO
--To Get Table Name
SELECT
	b.name AS TableName
	,c.name AS IndexName
	,c.type_desc AS IndexType
FROM sys.partitions a
INNER JOIN sys.objects b
	ON a.object_id = b.object_id
INNER JOIN sys.indexes c
	ON a.object_id = c.object_id AND a.index_id = C.index_id
WHERE partition_id IN ('1841441634')

SELECT 
	sys.fn_PhysLocFormatter(%%physloc%%) AS PageResource,
	%%lockres%% AS LockResource,*
FROM ParentTable
WHERE %%lockres%% IN()
