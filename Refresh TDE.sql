--When required to perform a refreshon a database that is protected by Tranparent Data Encryption (TDE),  it is important have the certifcates are sync between source and destination server. This article describe how to sync the certifcates prior to perform the move. The prefered method is to use the DBAM TDE tool, a link to this document is at the bottom of this article.
--1.	view the database TDE cerificate with this script, and identify the certifcate that you need.

-- view each database TDE certificate
USE master;
GO

SELECT
    database_name = d.name,
    cert_name = c.name
FROM sys.dm_database_encryption_keys dek
LEFT JOIN sys.certificates c
ON dek.encryptor_thumbprint = c.thumbprint
INNER JOIN sys.databases d
ON dek.database_id = d.database_id;
--2.	Backup the certificate. e.g.
--Ensure service account has proper access to backup location
-- Backup the certificate and private key
BACKUP CERTIFICATE [DEKCert_SP_CJPro_wa1_ConDB_001] TO FILE = 'J:\SQL2008\TDE\XYZ.cer'
WITH PRIVATE KEY ( 
    FILE = 'J:\SQL2008\TDE\ABC.pvk',
    ENCRYPTION BY PASSWORD = 'password' -- use DBAM tool in case this is sensitive
);
--3.	move the certicate to your target server
--4.	create the certificate on you target server. e.g.
--Ensure service account has proper access to certificate location
-- create the certificate on the target server with the correct private key
CREATE CERTIFICATE DEKCert_SP_CJPro_wa1_ConDB_001  
FROM FILE = 'J:\SQL2008\TDE\XYX.cer' 
WITH PRIVATE KEY (
    FILE = 'J:\SQL2008\TDE\ABC.pvk', 
    DECRYPTION BY PASSWORD = 'password' -- use DBAM tool in case this is sensitive
);
--5.	backup the database from your source server and move it to your target server
restore database from target server.
