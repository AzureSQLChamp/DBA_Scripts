-- Step 2 related
USE Distribution  
SELECT p.publication_id, p.publication, agent_id,  
Datediff(s,t.publisher_commit,t.distributor_commit) as 'Time To Dist (sec)',   
Datediff(s,t.distributor_commit,h.subscriber_commit) as 'Time To Sub (sec)'  
FROM MStracer_tokens t  
JOIN MStracer_history h  
ON t.tracer_id = h.parent_tracer_id  
JOIN MSpublications p 
ON p.publication_id = t.publication_id 

-- Step 3.1 related
USE distribution 
SELECT a.name AS agent_name, 
       CASE [runstatus]  
   WHEN 1 THEN 'Start' 
   WHEN 2 THEN 'Succeed' 
   WHEN 3 THEN 'In progress' 
   WHEN 4 THEN 'Idle' 
   WHEN 5 THEN 'Retry' 
   WHEN 6 THEN 'Fail' 
   END AS Status 
      ,[start_time] 
      ,h.[time] -- The time the message is logged. 
      ,[duration]  --The duration, in seconds, of the message session. 
      ,[comments] 
      ,h.[xact_seqno] -- The last processed transaction sequence number. 
      ,[delivery_time] -- The time first transaction is delivered. 
      ,[delivered_transactions] --The total number of transactions delivered in the session. 
      ,[delivered_commands] -- The total number of commands delivered in the session. 
      ,[average_commands] -- The average number of commands delivered in the session. 
      ,[delivery_rate] -- The average delivered commands per second. 
      ,[delivery_latency] -- The latency between the command entering the published database and being entered into the distribution database. In milliseconds. 
      ,[error_id] -- The ID of the error in the MSrepl_error system table. 
  ,e.error_text -- error text 
  FROM [distribution].[dbo].[MSlogreader_history] h 
  JOIN MSlogreader_agents a 
  ON a.id = h.agent_id 
  LEFT JOIN MSrepl_errors e 
  ON e.id = h.error_id  
ORDER BY h.time DESC

-- Step 3.2 related
USE distribution 
SELECT a.name AS agent_name, 
       CASE [runstatus]  
   WHEN 1 THEN 'Start' 
   WHEN 2 THEN 'Succeed' 
   WHEN 3 THEN 'In progress' 
   WHEN 4 THEN 'Idle' 
   WHEN 5 THEN 'Retry' 
   WHEN 6 THEN 'Fail' 
   END AS Status 
      ,[start_time] 
      ,h.[time] -- The time the message is logged. 
      ,[duration] --The duration, in seconds, of the message session. 
      ,[comments] 
      ,h.[xact_seqno] -- The last processed transaction sequence number. 
      ,[current_delivery_rate] -- The average number of commands delivered per second since the last history entry. 
  ,[current_delivery_latency] --The latency between the command entering the distribution database and being applied to the Subscriber since the last history entry. In milliseconds. 
      ,[delivered_transactions] --The total number of transactions delivered in the session. 
      ,[delivered_commands] -- The total number of commands delivered in the session. 
      ,[average_commands] -- The average number of commands delivered in the session. 
      ,[delivery_rate] -- The average delivered commands per second. 
      ,[delivery_latency] -- The latency between the command entering the distribution database and being applied to the Subscriber. In milliseconds.
  ,[total_delivered_commands] -- The total number of commands delivered since the subscription was created. 
      ,[error_id] -- The ID of the error in the MSrepl_error system table. 
  ,e.error_text -- error text 
  FROM MSdistribution_history h 
  JOIN MSdistribution_agents a 
  ON a.id = h.agent_id 
  LEFT JOIN MSrepl_errors e 
  ON e.id = h.error_id 
  ORDER BY h.time DESC
