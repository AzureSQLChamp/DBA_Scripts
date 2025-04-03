--Replication features is_installed status check on the instance

DECLARE @replication_installed int;  
EXEC @replication_installed = master.sys.sp_MS_replication_installed;  
SELECT @replication_installed as Is_Installed;

--check Database replication enabled status  
select @@servername
select name, is_published, is_subscribed, is_distributor
  from sys.databases
  where is_published = 1 or is_subscribed = 1 or is_distributor = 1

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
