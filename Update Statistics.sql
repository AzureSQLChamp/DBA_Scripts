--How to find out which indexes or statistics needs to be updates?
select
schemas.name as table_schema,
tbls.name as Object_name,
i.id as Object_id,
i.name as index_name,
i.indid as index_id,
i.rowmodctr as modifiedRows,
(select max(rowcnt) from sysindexes i2 where i.id = i2.id and i2.indid < 2) as rowcnt,
convert(DECIMAL(18,8), convert(DECIMAL(18,8),i.rowmodctr) / convert(DECIMAL(18,8),(select max(rowcnt) from sysindexes i2 where i.id = i2.id and i2.indid < 2))) as ModifiedPercent,
stats_date( i.id, i.indid ) as lastStatsUpdateTime
from sysindexes i
inner join sysobjects tbls on i.id = tbls.id
inner join sysusers schemas on tbls.uid = schemas.uid
inner join information_schema.tables tl
on tbls.name = tl.table_name
and schemas.name = tl.table_schema
and tl.table_type='BASE TABLE'
where 0 < i.indid and i.indid < 255
and table_schema <> 'sys'
and i.rowmodctr <> 0
and i.status not in (8388704,8388672)
and (select max(rowcnt) from sysindexes i2 where i.id = i2.id and i2.indid < 2) > 0
order by modifiedRows desc

--Note: You can use the following query on any SQL 2005+ instance to find out the % of rows modified and based on this decide if any indexes need to be rebuilt or statistics on the indexes need to be updated.
SELECT
 sch.name + '.' + so.name AS "Table",
ss.name AS "Statistic",
CASE
WHEN ss.auto_Created = 0 AND ss.user_created = 0 THEN 'Index Statistic'
WHEN ss.auto_created = 0 AND ss.user_created = 1 THEN 'User Created'
WHEN ss.auto_created = 1 AND ss.user_created = 0 THEN 'Auto Created'
WHEN ss.AUTO_created = 1 AND ss.user_created = 1 THEN 'Not Possible?'
END AS
"Statistic Type",
CASE
WHEN ss.has_filter = 1 THEN 'Filtered Index'
WHEN ss.has_filter = 0 THEN 'No Filter'
END AS
"Filtered?", 
    sp.rows AS "Rows", 
    sp.rows_sampled AS
"Rows Sampled", 
 sp.unfiltered_rows AS
"Unfiltered Rows",
sp.modification_counter AS
"Row Modifications",
sp.steps AS
"Histogram Steps"
FROM sys.stats ss
JOIN sys.objects so ON ss.object_id = so.object_id
JOIN sys.schemas sch ON so.schema_id = sch.schema_id
OUTER APPLY sys.dm_db_stats_properties(so.object_id, ss.stats_id) AS sp 
WHERE so.TYPE = 'U'
AND sp.last_updated <
getdate() 
ORDER BY sp.last_updated
DESC;

sp_helpstats N'[dbo].[GenuineList]','ALL'

SELECT object_name(sp.object_id) as "Table",
name as "Statistic", 
sp.stats_id as "Statistic ID",  
last_updated, 
rows, 
rows_sampled,
steps, 
unfiltered_rows,
modification_counter 
FROM sys.stats AS s 
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp 
WHERE sp.object_id = object_id('dbo.GenuineList');





