--Replication features is_installed status check on the instance

DECLARE @replication_installed int;  
EXEC @replication_installed = master.sys.sp_MS_replication_installed;  
SELECT @replication_installed as Is_Installed;

--check Database replication enabled status  
select @@servername
select name, is_published, is_subscribed, is_distributor
  from sys.databases
  where is_published = 1 or is_subscribed = 1 or is_distributor = 1


/*REPLICATION SETUP
PASSWORD: All replication agent passwords set to 'Admin@12345' */
-- STEP 1: Configure Distributor on: DISTRIBUTOR SERVER
USE master;
EXEC sp_adddistributor 
@distributor = N'DISTRIBUTOR SERVER', 
@password = N'Admin@12345'; -- Add distributor and set admin password


---- 1. How to Change the Distributor Admin password
--EXEC sp_changedistributor_password 
-- @password = N'NewStrongPasswordHere';

----Verify
--SELECT name, is_distributor
--FROM sys.servers
--WHERE is_distributor = 1;

-- Verify distributor registered in sys.servers
SELECT name AS distributor_alias,
data_source AS distributor_instance,
is_distributor
FROM sys.servers
WHERE is_distributor = 1;

-- Create distribution database
EXEC sp_adddistributiondb 
@database = N'distribution_db',
@security_mode = 1;

-- Verify distribution DB created and online
SELECT name, state_desc 
FROM sys.databases 
WHERE name = 'distribution_db';

-- Link the publisher to the distributor
USE distribution_db;
EXEC sp_adddistpublisher 
@publisher = N'PUBLISHER SERVER',
@distribution_db = N'distribution_db',
@security_mode = 1;

-- Verify publisher link details
SELECT name, distribution_db, working_directory
FROM msdb.dbo.MSdistpublishers;

-- How to Change Snapshot Folder (working_directory) for a Publisher on DISTRIBUTOR
-- Example:
-- EXEC sp_changedistpublisher 
-- @publisher = N'PUBLISHER SERVER',
-- @property = N'working_directory',
-- @value = N'C:\Replication\Snapshots';

-- verify publisher and snapshot folder
SELECT name, distribution_db, working_directory
FROM msdb.dbo.MSdistpublishers
WHERE name = N'PUBLISHER SERVER';

-- STEP 2: Configure Publisher on: PUBLISHER SERVER
USE master;
EXEC sp_adddistributor 
@distributor = N'DISTRIBUTOR SERVER',
@password = N'Admin@12345'; -- Attach publisher to the distributor

--Verify: Publisher now has distributor linked
SELECT @@SERVERNAME --current server name
SELECT name AS distributor_alias,
data_source AS distributor_instance,
is_distributor
FROM sys.servers
WHERE is_distributor = 1;

---- Register subscriber at publisher (optional)
--EXEC sp_addsubscriber
--@subscriber = N'SUBSCRIBER SERVER',
--@type = 0,
--@description = N'Subscriber instance';

---- Verify: Subscriber is registered
--SELECT subscriber, type, description
--FROM syssubscriptions s
--JOIN master.dbo.sysservers ss
-- ON s.srvid = ss.srvid
--WHERE ss.srvname = N'SUBSCRIBER SERVER';

-- Enable publication on DB1
EXEC sp_replicationdboption 
@dbname = N'DB1',
@optname = N'publish',
@value = N'true';

-- Verify DB1 is published
SELECT @@SERVERNAME --current server name
SELECT name, is_published, is_subscribed 
FROM sys.databases 
WHERE name = 'DB1';

-- STEP 3: Create the Publication on: PUBLISHER SERVER
USE DB1;
EXEC sp_addpublication 
@publication = N'PUB_DB1-SUB_DB2',
@status = N'active',
@allow_push = N'true',
@allow_pull = N'true',
@allow_anonymous = N'true',
@immediate_sync = N'true',
@retention = 0,
@repl_freq = N'continuous',
@independent_agent = N'true',
@enabled_for_internet = N'false',
@snapshot_in_defaultfolder= N'true';

-- Verify publication exists and properties
EXEC sp_helppublication @publication = N'PUB_DB1-SUB_DB2';

-- Create snapshot agent job for this publication
EXEC sp_addpublication_snapshot 
@publication = N'PUB_DB1-SUB_DB2',
@frequency_type = 1, -- Manual start
@job_login = N'DOMAIN\ReplSrv',
@job_password = N'Admin@12345',
@publisher_security_mode = 0,
@publisher_login = N'replicationadmin',
@publisher_password = N'Admin@12345';

-- STEP 4: Add All Articles on: PUBLISHER SERVER
USE DB1;
-- Add individual tables as articles
EXEC sp_addarticle @publication = N'PUB_DB1-SUB_DB2', @article = N'brands', @source_owner = N'production', @source_object = N'brands', @type = N'logbased';
EXEC sp_addarticle @publication = N'PUB_DB1-SUB_DB2', @article = N'categories', @source_owner = N'production', @source_object = N'categories', @type = N'logbased';
EXEC sp_addarticle @publication = N'PUB_DB1-SUB_DB2', @article = N'products', @source_owner = N'production', @source_object = N'products', @type = N'logbased';
EXEC sp_addarticle @publication = N'PUB_DB1-SUB_DB2', @article = N'stocks', @source_owner = N'production', @source_object = N'stocks', @type = N'logbased';
-- Verify all articles are registered to the publication
EXEC sp_helparticle @publication = N'PUB_DB1-SUB_DB2';

-- STEP 5: Add Push Subscription on: PUBLISHER SERVER
EXEC sp_addsubscription 
@publication = N'PUB_DB1-SUB_DB2',
@subscriber = N'SUBSCRIBER SERVER',
@destination_db = N'DB2',
@subscription_type = N'push',
@sync_type = N'automatic';
-- Verify subscription exists and status
EXEC sp_helpsubscription @publication = N'PUB_DB1-SUB_DB2';

-- Run snapshot immediately to generate schema/data for subscribers
EXEC sp_startpublication_snapshot 
@publication = N'PUB_DB1-SUB_DB2';

-- Verify snapshot agent at Distributor
SELECT publication, name
FROM distribution_db.dbo.MSsnapshot_agents
WHERE publication = N'PUB_DB1-SUB_DB2';

-SELECT 'sales.stores', COUNT(*) FROM sales.stores;

--ADD ARTICLES TO EXSTING REPLICATION


-- STEP 1 – Check current publication properties
EXEC sp_helppublication @publication = N'PUB_DB1-SUB_DB2';
GO

-- Disable allow_anonymous and immediate_sync to allow schema changes
EXEC sp_changepublication
@publication = N'PUB_DB1-SUB_DB2',
@property = N'allow_anonymous',
@value = 'FALSE';
GO

EXEC sp_changepublication
@publication = N'PUB_DB1-SUB_DB2',
@property = N'immediate_sync',
@value = 'FALSE';
GO

-- Verify property changes
EXEC sp_helppublication @publication = N'PUB_DB1-SUB_DB2';
GO

-- STEP 2 – Add new articles from sales schema

USE DB1;
GO
EXEC sp_addarticle
@publication = N'PUB_DB1-SUB_DB2',
@article = N'sales_customers',
@source_owner = N'sales',
@source_object = N'customers',
@type = N'logbased',
@schema_option = 0x000000000803509F,
@identityrangemanagementoption = N'manual',
@force_invalidate_snapshot = 1;
GO

EXEC sp_addarticle
@publication = N'PUB_DB1-SUB_DB2',
@article = N'sales_order_items',
@source_owner = N'sales',
@source_object = N'order_items',
@type = N'logbased',
@schema_option = 0x000000000803509F,
@identityrangemanagementoption = N'manual',
@force_invalidate_snapshot = 1;
GO

EXEC sp_addarticle
@publication = N'PUB_DB1-SUB_DB2',
@article = N'sales_orders',
@source_owner = N'sales',
@source_object = N'orders',
@type = N'logbased',
@schema_option = 0x000000000803509F,
@identityrangemanagementoption = N'manual',
@force_invalidate_snapshot = 1;
GO

EXEC sp_addarticle
@publication = N'PUB_DB1-SUB_DB2',
@article = N'sales_staffs',
@source_owner = N'sales',
@source_object = N'staffs',
@type = N'logbased',
@schema_option = 0x000000000803509F,
@identityrangemanagementoption = N'manual',
@force_invalidate_snapshot = 1;
GO

EXEC sp_addarticle
@publication = N'PUB_DB1-SUB_DB2',
@article = N'sales_stores',
@source_owner = N'sales',
@source_object = N'stores',
@type = N'logbased',
@schema_option = 0x000000000803509F,
@identityrangemanagementoption = N'manual',
@force_invalidate_snapshot = 1;
GO

-- Verify all articles now in publication
EXEC sp_helparticle @publication = N'PUB_DB1-SUB_DB2';
GO


-- STEP 3 – Refresh subscriptions

EXEC sp_refreshsubscriptions @publication = N'PUB_DB1-SUB_DB2';
GO

-- STEP 4 – (Manual or scripted) Start Snapshot Agent & Log Reader
-- Can be triggered via Replication Monitor or sp_start_job at Distributor
-- Example:
-- EXEC msdb.dbo.sp_start_job @job_name = N'PUB_DB1-SUB_DB2-DB1-Snapshot';

-------------------------------------------------------------------------------
-- STEP 5 – Re‑enable immediate_sync and allow_anonymous

EXEC sp_changepublication
@publication = N'PUB_DB1-SUB_DB2',
@property = N'immediate_sync',
@value = 'TRUE';
GO

EXEC sp_changepublication
@publication = N'PUB_DB1-SUB_DB2',
@property = N'allow_anonymous',
@value = 'TRUE';
GO

-- Final verification of publication settings
EXEC sp_helppublication @publication = N'PUB_DB1-SUB_DB2';
GO

	
--Replication details
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED 

IF EXISTS (SELECT 1 FROM master..sysdatabases WHERE name = 'Distribution')
BEGIN
-- Get the publication name based on article 
SELECT DISTINCT  
	p.publication							AS Publication_Name
	,srv.srvname							AS Publication_Server  
	,a.publisher_db							AS Publication_Database
	,a.article							AS Publication_Table_Name
	,ss.srvname							AS Subscription_Server  
	,s.subscriber_db						AS Subscription_Database
	,a.destination_object 						AS Subscription_Table_Name
	,da.subscriber_login				 		AS Subscription_Login
	,da.name							AS Distribution_Agent_Job_Name
	FROM Distribution..MSArticles a  
	JOIN Distribution..MSpublications p 
		ON a.publication_id = p.publication_id 
	JOIN Distribution..MSsubscriptions s 
		ON p.publication_id = s.publication_id 
	JOIN master..sysservers ss 
		ON s.subscriber_id = ss.srvid 
	JOIN master..sysservers srv 
		ON srv.srvid = p.publisher_id 
	JOIN Distribution..MSdistribution_agents da 
		ON da.publisher_id = p.publisher_id  
		AND da.subscriber_id = s.subscriber_id 
	ORDER BY 1,2,3 
END

--Replication Details along with Agent jobs info
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF EXISTS (SELECT 1 FROM master.dbo.sysdatabases WHERE name = 'distribution')
BEGIN
    PRINT 'Distribution database exists. Running the script...';
    SELECT 
        pub.publication AS Publication_Name,
        pub.publisher_db AS Publication_Database,
        p_srv.srvname AS Publisher_Server,  -- Corrected Publisher Server
        art.source_owner + '.' + art.source_object AS Publication_Table_Name,
        sub.subscriber_db AS Subscription_Database,
        s_srv.srvname AS Subscription_Server,
        ISNULL(art.destination_owner + '.' + art.destination_object, art.source_owner + '.' + art.source_object) AS Subscription_Table_Name,
        sj.name AS Snapshot_Agent_Job_Name,
        lj.name AS Log_Reader_Agent_Job_Name,
        dj.name AS Distributor_Agent_Job_Name

    FROM distribution.dbo.MSpublications pub
    JOIN distribution.dbo.MSarticles art ON pub.publication_id = art.publication_id
    JOIN distribution.dbo.MSsubscriptions sub ON pub.publication_id = sub.publication_id
    JOIN master.dbo.sysservers p_srv ON pub.publisher_id = p_srv.srvid  
    JOIN master.dbo.sysservers s_srv ON sub.subscriber_id = s_srv.srvid  
    LEFT JOIN distribution.dbo.MSsnapshot_agents snap ON pub.publication = snap.publication
    LEFT JOIN msdb.dbo.sysjobs sj ON snap.job_id = sj.job_id  
    LEFT JOIN distribution.dbo.MSlogreader_agents logr ON pub.publisher_db = logr.publisher_db
    LEFT JOIN msdb.dbo.sysjobs lj ON logr.job_id = lj.job_id  
    LEFT JOIN distribution.dbo.MSdistribution_agents dist 
        ON sub.subscriber_id = dist.subscriber_id 
        AND sub.subscriber_db = dist.subscriber_db  
    LEFT JOIN msdb.dbo.sysjobs dj ON dist.job_id = dj.job_id;  
END
ELSE
BEGIN
    PRINT 'Distribution database does not exist. Exiting script...';
END;

--Replication errors
SELECT * FROM MSrepl_errors ORDER BY time desc

--Change Replication Administrative (distributor_admin) login password
USE master;
EXEC sp_changedistributor_password @password;

===========================
SELECT 
  msp.publication AS PublicationName,
  msa.publisher_db AS DatabaseName,
  msa.article AS ArticleName,
  msa.source_owner AS SchemaName,
  msa.source_object AS TableName, *
FROM distribution.dbo.MSarticles msa
JOIN distribution.dbo.MSpublications msp ON msa.publication_id = msp.publication_id
ORDER BY 
  msp.publication, 
  msa.article



USE Distribution;
select * from distribution.dbo.msrepl_errors order by time desc 
GO

EXEC sp_browsereplcmds '0x0003A857003B8097007D00000000', '0x0003A857003B8097007D00000000'
GO

select * from distribution.dbo.MSrepl_commands where xact_seqno >(select transaction_timestamp from EM2_RPT.dbo.msreplication_subscriptions) 
GO
SELECT * 
   FROM distribution.dbo.MSarticles
   WHERE article_id in (
      SELECT article_id 
         FROM MSrepl_commands
         WHERE xact_seqno = 0x0003A857003B8097007D)

select immediate_sync,allow_anonymous,* from distribution.dbo.MSpublications 
