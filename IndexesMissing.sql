USE trumotDB
SET NOCOUNT ON; SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--SELECT DATEDIFF(DAY, create_date, CURRENT_TIMESTAMP)dif_dd, create_date FROM sys.databases WHERE database_id = 2

DECLARE @online bit; SELECT	@online = 0;  

SELECT TOP 50
  -- db_name(d.database_id)		AS [database]
	 SCHEMA_NAME(t.schema_id) [schema]
	,OBJECT_NAME(d.object_id) AS [object]
	,d.equality_columns                     
	,d.inequality_columns
	,d.included_columns
	,s.unique_compiles      
	,s.user_seeks           
	,s.user_scans           
	,s.last_user_seek          
	,s.last_user_scan          
	,s.avg_total_user_cost    
	,s.avg_user_impact    	
	,command = 'CREATE NONCLUSTERED INDEX IX_' + OBJECT_NAME(d.object_id) + '__' + REPLACE(REPLACE(REPLACE(ISNULL(d.equality_columns, ''), '[','') , ']',''), ', ','_') 
		+ CASE WHEN d.inequality_columns IS NOT NULL THEN '_' ELSE '' END + REPLACE(REPLACE(REPLACE(ISNULL(d.inequality_columns,''), '[','') ,']','') ,', ','_')
		+ ' ON [' + SCHEMA_NAME(t.schema_id) + '].[' + OBJECT_NAME(d.object_id) + '] ('
		+ CASE WHEN d.equality_columns IS NOT NULL THEN d.equality_columns ELSE '' END 
		+ CASE WHEN d.inequality_columns IS NOT NULL AND d.equality_columns IS NOT NULL THEN ', ' + d.inequality_columns ELSE ISNULL(d.inequality_columns, '') END + ')'
		+ CASE WHEN d.included_columns IS NOT NULL THEN ' INCLUDE (' + d.included_columns + ')' ELSE '' END
		+ ' WITH (ONLINE = ' + CASE WHEN @online = 1 THEN 'ON);' ELSE 'OFF);' END
FROM sys.dm_db_missing_index_details d
INNER JOIN sys.dm_db_missing_index_groups g ON d.index_handle = g.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats s ON g.index_group_handle = s.group_handle
INNER JOIN sys.tables t ON t.object_id = d.[object_id]
WHERE 1=1
AND OBJECTPROPERTY(d.[object_id], 'IsMsShipped') = 0
--AND t.is_memory_optimized <> 1 
AND d.database_id = DB_ID()
--AND OBJECT_NAME(d.object_id) NOT IN ( '','','','','','','','','','','','','','','','','','','','','','','','')
AND OBJECT_NAME(d.object_id) LIKE 'ASK_TO_PAY_P_TBL'
--AND avg_user_impact > 50
ORDER BY s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks + s.user_scans) DESC;

--select OBJECT_NAME(object_id), * from sys.sql_modules where definition like '%IX_ASK_TO_PAY_P_TBL_COID%'

--EXEC sp_helpindex2 @Table = 'ASK_TO_PAY_P_TBL', @Schema = 'dbo', @IndexExtendedInfo = 0, @MissingIndexesInfo = 1, @ColumnsInfo = 1

drop index IX_ASK_TO_PAY_P_TBL_COID on ASK_TO_PAY_P_TBL
	
