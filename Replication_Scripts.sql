
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
