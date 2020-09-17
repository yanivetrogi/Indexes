-- 1. Before index creation execute (on the same session) 
SET STATISTICS PROFILE ON;


-- 2. When index creation runs, use following query from another session in order to monitor progress
SELECT session_id, request_id, physical_operator_name, node_id, thread_id, row_count, estimate_row_count
FROM sys.dm_exec_query_profiles
WHERE session_id = 96
ORDER BY node_id DESC, thread_id;


-- Percent progress
WITH CTE AS
(
	SELECT 
		session_id, request_id, physical_operator_name, node_id, thread_id, row_count, estimate_row_count,
		SUM(estimate_row_count) OVER(PARTITION BY session_id, physical_operator_name) AS TotalRows,
		SUM(row_count) OVER(PARTITION BY session_id, physical_operator_name) AS TotalProcessedRows
	FROM sys.dm_exec_query_profiles
	WHERE session_id = 96
)
SELECT session_id, request_id, physical_operator_name, node_id, thread_id, row_count, estimate_row_count,
	IIF(TotalRows = 0, 0, CONVERT(DECIMAL(5,2), TotalProcessedRows*100.0/TotalRows)) AS PctCompleted
FROM CTE
ORDER BY node_id DESC, thread_id;
------------------------------------------------------------


/*
	https://dba.stackexchange.com/questions/139191/sql-server-how-to-track-progress-of-create-index-command/139225?fbclid=IwAR1PfPs27sTz4e-SD3H2qyOU6-1L8PmSxLwGqg3X5-Y1HJgO_5OuhAaFAuc#139225
	Get index createion estimation
	Requires SET STATISTICS PROFILE ON; or SET STATISTICS XML ON; at the session creating the index

*/
/*
SELECT session_id, request_id, physical_operator_name, node_id, 
       thread_id, row_count, estimate_row_count
FROM sys.dm_exec_query_profiles

ORDER BY  node_id DESC, thread_id
*/
SELECT   
       node_id,
	   session_id,
       physical_operator_name, 
       SUM(row_count) row_count, 
       SUM(estimate_row_count) AS estimate_row_count,
       CAST(SUM(row_count)*100 AS float)/SUM(estimate_row_count)  as estimate_percent_complete
FROM sys.dm_exec_query_profiles   
--WHERE session_id=54  
GROUP BY session_id, node_id,physical_operator_name  
ORDER BY session_id, node_id desc;



--DECLARE @SPID int = 68
;WITH agg
AS (SELECT SUM(qp.[row_count])                                                                                  AS [RowsProcessed]
          ,SUM(qp.[estimate_row_count])                                                                         AS [TotalRows]
          ,MAX(qp.last_active_time) - MIN(qp.first_active_time)                                                 AS [ElapsedMS]
          ,MAX(IIF(qp.[close_time] = 0 AND qp.[first_row_time] > 0, [physical_operator_name], N'<Transition>')) AS [CurrentStep]
    FROM sys.dm_exec_query_profiles qp
    WHERE 1=1
	--AND qp.[physical_operator_name] IN (N'Table Scan', N'Clustered Index Scan', N'Sort')
AND   qp.[session_id] <> @@spid --@SPID OR @SPID IS NULL)
	)
,comp
AS (SELECT *
          ,([TotalRows] - [RowsProcessed]) AS [RowsLeft]
          ,([ElapsedMS] / 1000.0)          AS [ElapsedSeconds]
    FROM agg
	)

SELECT [CurrentStep]
      ,[TotalRows]
      ,[RowsProcessed]
      ,[RowsLeft]
      ,CONVERT(decimal(5, 2), (([RowsProcessed] * 1.0) / [TotalRows]) * 100)           AS [PercentComplete]
      ,CAST([ElapsedSeconds] AS decimal) ElapsedSeconds
      ,CAST(([ElapsedSeconds] / [RowsProcessed]) * [RowsLeft]  AS decimal)                          AS [EstimatedSecondsLeft]
      ,DATEADD(SECOND, (([ElapsedSeconds] / [RowsProcessed]) * [RowsLeft]), GETDATE()) AS [EstimatedCompletionTime]
FROM comp;
