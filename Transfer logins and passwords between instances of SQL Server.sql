SET NOCOUNT ON
-- Scripting Out the Logins To Be Created
SELECT 'IF (SUSER_ID('+QUOTENAME(SP.name,'''')+') IS NULL) BEGIN CREATE LOGIN ' +QUOTENAME(SP.name)+
			   CASE 
					WHEN SP.type_desc = 'SQL_LOGIN' THEN ' WITH PASSWORD = ' +CONVERT(NVARCHAR(MAX),SL.password_hash,1)+ ' HASHED, CHECK_EXPIRATION = ' 
						+ CASE WHEN SL.is_expiration_checked = 1 THEN 'ON' ELSE 'OFF' END +', CHECK_POLICY = ' +CASE WHEN SL.is_policy_checked = 1 THEN 'ON,' ELSE 'OFF,' END
					ELSE ' FROM WINDOWS WITH'
				END 
	   +' DEFAULT_DATABASE=[' +SP.default_database_name+ '], DEFAULT_LANGUAGE=[' +SP.default_language_name+ '] END;' COLLATE SQL_Latin1_General_CP1_CI_AS AS [-- Logins To Be Created --]
FROM sys.server_principals AS SP LEFT JOIN sys.sql_logins AS SL
		ON SP.principal_id = SL.principal_id
WHERE SP.type IN ('S','G','U')
		AND SP.name NOT LIKE '##%##'
		AND SP.name NOT LIKE 'NT AUTHORITY%'
		AND SP.name NOT LIKE 'NT SERVICE%'
		AND SP.name <> ('sa');

-- Scripting Out the Role Membership to Be Added
SELECT 
'EXEC master..sp_addsrvrolemember @loginame = N''' + SL.name + ''', @rolename = N''' + SR.name + '''
' AS [-- Server Roles the Logins Need to be Added --]
FROM master.sys.server_role_members SRM
	JOIN master.sys.server_principals SR ON SR.principal_id = SRM.role_principal_id
	JOIN master.sys.server_principals SL ON SL.principal_id = SRM.member_principal_id
WHERE SL.type IN ('S','G','U')
		AND SL.name NOT LIKE '##%##'
		AND SL.name NOT LIKE 'NT AUTHORITY%'
		AND SL.name NOT LIKE 'NT SERVICE%'
		AND SL.name <> ('sa');


-- Scripting out the Permissions to Be Granted
SELECT 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN SrvPerm.state_desc 
		ELSE 'GRANT' 
	END
    + ' ' + SrvPerm.permission_name + ' TO [' + SP.name + ']' + 
	CASE WHEN SrvPerm.state_desc <> 'GRANT_WITH_GRANT_OPTION' 
		THEN '' 
		ELSE ' WITH GRANT OPTION' 
	END collate database_default AS [-- Server Level Permissions to Be Granted --] 
FROM sys.server_permissions AS SrvPerm 
	JOIN sys.server_principals AS SP ON SrvPerm.grantee_principal_id = SP.principal_id 
WHERE   SP.type IN ( 'S', 'U', 'G' ) 
		AND SP.name NOT LIKE '##%##'
		AND SP.name NOT LIKE 'NT AUTHORITY%'
		AND SP.name NOT LIKE 'NT SERVICE%'
		AND SP.name <> ('sa');

SET NOCOUNT OFF
