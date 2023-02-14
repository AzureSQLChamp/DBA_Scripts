--Script Permissions for SQL Server database
set nocount on
 
select 'use [' + DB_NAME() + ']'
union all
select 'go'
union all
 
-- create database users 
select 'create user [' +
 dp.name collate latin1_general_ci_as +
  '] for login [' +
  sp.name collate latin1_general_ci_as +
  ']' +
  case when dp.[default_schema_name] is null then '' else ' with default_schema=[' + dp.[default_schema_name] + ']' end +
  char(10) + 'go' 
 from sys.database_principals as dp
 inner join sys.server_principals sp on dp.sid = sp.sid
 where dp.[type] in ('u','g','s')
 and dp.name not in ('public','dbo','guest','information_schema','sys','db_owner',
'db_accessadmin','db_securityadmin','db_ddladmin','db_backupoperator','db_datareader','db_datawriter','db_denydatareader','db_denydatawriter')
  union all
 
 -- create database roles
select 'create role [' +
 dp.name +
  '] authorization [dbo] ' + char(10) + 'go'
 from sys.database_principals as dp
       where dp.[type] = 'r' 
       and dp.name not in ('public','dbo','guest','information_schema','sys','db_owner','db_accessadmin',
'db_securityadmin','db_ddladmin','db_backupoperator','db_datareader','db_datawriter','db_denydatareader','db_denydatawriter')
 union all
 
-- add users to roles
select 'exec dbo.sp_addrolemember @rolename=N''' +
 dp.name +
  ''', @membername=N''' +
  dpmember.name + '''' + 
  char(10) + 'go' 
from sys.database_principals as dp
         inner join sys.database_role_members as drm on dp.[principal_id] = drm.[role_principal_id] 
         inner join sys.database_principals  as dpmember on drm.[member_principal_id] = dpmember.[principal_id]
         inner join sys.server_principals sp on dpmember.sid = sp.sid
 where dpmember.[name] not like 'dbo'
union all
 
-- grant permission to roles
select 'if exists (select * from sys.objects where name = N''' + o.name + ''') and exists ' +
 '(select * from sys.schemas where name = N''' + s.name + ''')' +
  char(10) + 
  CASE WHEN dp.state_desc = 'GRANT_WITH_GRANT_OPTION' THEN 'GRANT' ELSE dp.state_desc END + ' ' + 
  dp.permission_name + ' on [' + 
  s.name + '].[' + o.name + '] to [' + 
  dpr.name + ']' + 
  CASE WHEN dp.state_desc = 'GRANT_WITH_GRANT_OPTION' THEN ' WITH GRANT OPTION' ELSE '' END + 
   ' as [dbo]' +
    char(10) + 'go'
 from sys.database_permissions as dp
         inner join sys.objects as o on dp.major_id = o.object_id
         inner join sys.schemas as s on o.schema_id = s.schema_id
         inner join sys.database_principals as dpr on dp.grantee_principal_id = dpr.principal_id
 where dpr.[type] = 'R'
union all
 
-- grant permission to users
select 'if exists (select * from sys.objects where name = N''' + o.name + ''') and exists ' +
 '(select * from sys.schemas where name = N''' + s.name + ''')' +
  char(10) + 
 CASE WHEN dp.state_desc = 'GRANT_WITH_GRANT_OPTION' THEN 'GRANT' ELSE dp.state_desc END + ' ' + 
 dp.permission_name + ' on [' + 
 s.name + '].[' + o.name + '] to [' +
 dpr.name + ']' + 
 CASE WHEN dp.state_desc = 'GRANT_WITH_GRANT_OPTION' THEN ' WITH GRANT OPTION' ELSE '' END + 
 ' as [dbo]' +
 char(10) + 'go'
from sys.database_permissions as dp
 inner join sys.objects as o on dp.major_id = o.object_id
 inner join sys.schemas as s on o.schema_id = s.schema_id
 inner join sys.database_principals as dpr on dp.grantee_principal_id = dpr.principal_id
 inner join sys.server_principals sp on dpr.sid = sp.sid
where dpr.[type] IN ('S','U','G')
 
set nocount off




--Remove all schemas, roles and users from a database:
set nocount on
 
select 'use [' + DB_NAME() + '] '
union all
select 'go'
 
union all
 
-- Remove all users from all roles
select distinct 'exec dbo.sp_droprolemember @rolename=N''' +
       dp.name +
       ''', @membername=N''' +
       dpmember.name + '''' + 
       char(10) + 'go' 
from sys.database_principals as dp
       inner join sys.database_role_members as drm on dp.[principal_id] = drm.[role_principal_id] 
       inner join sys.database_principals  as dpmember on drm.[member_principal_id] = dpmember.[principal_id]
where dpmember.[name] not like 'dbo'
 
union all
 
-- Drop all schemas named as non-builtin users
select distinct 'drop schema [' + s.name + '] '+
       char(10) + 'go' 
from sys.schemas s inner join sys.database_principals dp on dp.name = s.name
where s.name NOT IN ('dbo', 'guest', 'information_schema','sys','db_owner','db_accessadmin','db_securityadmin','db_ddladmin','db_backupoperator','db_datareader','db_datawriter','db_denydatareader','db_denydatawriter')
 
union all
 
-- Drop all users (except builtin)
select distinct 'drop user [' +
       dp.name + '] ' +
       char(10) + 'go' 
from sys.database_principals as dp
where dp.[type] in ('u','g','s')
       and dp.name not in ('dbo','guest','information_schema','sys')
 
union all
 
-- Drop all roles
select distinct 'drop role [' +
       dp.name + '] ' +
       char(10) + 'go' 
from sys.database_principals as dp
where dp.name not in ('public','db_owner','db_accessadmin','db_securityadmin','db_ddladmin','db_backupoperator','db_datareader','db_datawriter','db_denydatareader','db_denydatawriter')
       and dp.type = 'r'
 
set nocount off


