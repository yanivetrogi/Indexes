-- Get all SQL Statements with "table scan" in cached query plan 
USE BurstingDB;
;WITH  
 XMLNAMESPACES 
    (DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'   
            ,N'http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS ShowPlan)  
,s AS 
    (
			SELECT TOP 10
							s.plan_handle 
						 ,SUM(s.execution_count) AS ExecutionCount 
						 ,SUM(s.total_worker_time) AS TotalWorkTime 
						 ,SUM(s.total_logical_reads) AS TotalLogicalReads 
						 ,SUM(s.total_logical_writes) AS TotalLogicalWrites 
						 ,SUM(s.total_elapsed_time) AS TotalElapsedTime 
						 ,MAX(s.last_execution_time) AS LastExecutionTime 
			 FROM sys.dm_exec_query_stats AS s 
			 GROUP BY s.plan_handle
			 ORDER BY SUM(s.total_worker_time) DESC 
		 )    
SELECT s.[ExecutionCount] 
      ,s.[TotalWorkTime] 
      ,s.[TotalLogicalReads] 
      ,s.[TotalLogicalWrites] 
      ,s.[TotalElapsedTime] 
      ,s.[LastExecutionTime] 
      ,cp.[objtype] AS [ObjectType] 
      ,cp.[cacheobjtype] AS [CacheObjectType] 
      ,DB_NAME(t.[dbid]) AS [DatabaseName] 
      ,OBJECT_NAME(t.[objectid], t.[dbid]) AS [ObjectName] 
      ,t.[text] AS [Statement]       
      ,p.[query_plan] AS [QueryPlan] 
FROM sys.dm_exec_cached_plans AS cp 
INNER JOIN s ON cp.plan_handle = s.plan_handle      
CROSS APPLY sys.dm_exec_sql_text(cp.[plan_handle]) AS t 
CROSS APPLY sys.dm_exec_query_plan(cp.[plan_handle]) AS p 
WHERE 1=1
--AND p.[query_plan].exist('data(//RelOp[@PhysicalOp="Table Scan"][1])') = 1  /* Index Scan */
AND p.[query_plan].exist('data(//RelOp[@PhysicalOp="Parallelism"][1])') = 1 
AND s.[ExecutionCount] > 1  
AND cp.[usecounts] > 1 
ORDER BY s.[TotalWorkTime] DESC ,s.ExecutionCount DESC;