--How to start or stop an endpoint in SQL Server
--To list all endpoints in a SQL Server instance, you can query sys.endpoints catalog view that contains one row for each endpoint:
select * from sys.endpoints
To stop an endpoint:
ALTER ENDPOINT endpoint_name STATE = STOPPED
To start an endpoint:
ALTER ENDPOINT endpoint_name STATE = STARTED

