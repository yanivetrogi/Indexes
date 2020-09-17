USE StackOverflow2010;
SET NOCOUNT ON; SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
--SELECT DATEDIFF(DAY, create_date, CURRENT_TIMESTAMP)dif_dd, create_date FROM sys.databases WHERE database_id = 2

DECLARE @index_access_count int = 10; 

SELECT 
	'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(OBJECT_NAME(i.object_id)) + ';'
	,@@SERVERNAME AS [server]
	,DB_NAME(database_id) AS [database]
	,SCHEMA_NAME(t.schema_id) [schema]
	,OBJECT_NAME(i.object_id) AS [object]
	,i.name AS [index]
	,isize.size_mb
	,s.user_updates
	,s.user_seeks
	,s.user_scans
	,s.user_lookups
	,CASE WHEN i.[type] = 0 THEN 'Heap' WHEN i.[type]= 1 THEN 'Clustered' WHEN i.type = 2 THEN 'Nonclustered' WHEN i.[type] = 3 THEN 'XML' ELSE 'NA' END AS index_type
	,i.is_primary_key
	,CASE WHEN i.is_unique = 1 THEN 'UI' WHEN i.is_unique_constraint = 1 THEN '	UC' ELSE 'NA' END AS [is_unique]
FROM sys.indexes i  
INNER JOIN sys.dm_db_index_usage_stats s ON s.object_id = i.object_id AND i.index_id = s.index_id 
INNER JOIN sys.tables t ON t.object_id = i.object_id
CROSS APPLY (SELECT  p.index_id
                    ,SUM(p.rows) AS rows
                    ,SUM(total_pages) / 128 AS size_mb
              FROM sys.partitions p
              INNER JOIN sys.allocation_units au ON au.container_id = p.partition_id
              WHERE p.object_id = i.object_id AND p.index_id = i.index_id
              GROUP BY p.index_id
			) isize
WHERE OBJECTPROPERTY(i.object_id, 'IsIndexable') = 1 AND OBJECTPROPERTY(i.object_id, 'IsSystemTable') = 0 AND s.index_id > 0

AND (s.index_id IS NULL OR (ISNULL(s.user_updates, 0) >= 0 AND ISNULL(s.user_seeks, 0) <= @index_access_count AND ISNULL(s.user_scans, 0) <= @index_access_count AND ISNULL(s.user_lookups, 0) <= @index_access_count ) )

AND database_id = DB_ID()	-- current db
AND i.type <> 1				-- exclude clustered indexes
AND i.is_primary_key <> 1	-- exclude PKs
AND i.is_unique = 0			-- exclude inique
ORDER BY OBJECT_NAME(i.object_id) DESC, s.user_updates DESC;

--SELECT OBJECT_NAME(object_id),  * FROM sys.sql_modules WHERE definition LIKE'%%'
