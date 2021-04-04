--SELECT * FROM sys.databases WHERE database_id = 2
USE trumotDB

SET NOCOUNT ON; SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
SELECT TOP 20
     s.execution_count
    ,(s.total_physical_reads + s.total_logical_reads + s.total_logical_writes) AS [Total IO]
    ,(s.total_physical_reads + s.total_logical_reads + s.total_logical_writes) /s.execution_count AS [Avg IO]   
    ,DB_NAME(t.[dbid])				 AS [database]
    ,OBJECT_NAME(t.objectid, t.dbid) AS [object]
	,SUBSTRING(t.[text], s.statement_start_offset/2, ( CASE  WHEN s.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), t.[text])) * 2  ELSE s.statement_end_offset  END - s.statement_start_offset)/2  ) AS query_text
    ,p.query_plan 
FROM sys.dm_exec_query_stats s 
CROSS APPLY sys.dm_exec_sql_text (s.[sql_handle]) t 
OUTER APPLY sys.dm_exec_query_plan(s.plan_handle) p 
WHERE 1=1 
AND t.dbid = DB_ID() 
AND p.query_plan.exist('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes') = 1  
--AND CAST(p.query_plan AS nvarchar(max)) LIKE N'%IX_MSdistribution_history%'
ORDER BY [Total IO] DESC, s.execution_count DESC;
