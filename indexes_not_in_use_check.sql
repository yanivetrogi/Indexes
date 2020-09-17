--SELECT DATEDIFF(DAY, create_date, CURRENT_TIMESTAMP) up_time_dd FROM sys.databases WHERE database_id = 2;
--use EnforcementManagment
USE EnforcementManagment
SET NOCOUNT ON; SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @table sysname = 'dt_case'


DECLARE @is_check bit = 1

-- The threshold for index Seeks, Scans


DECLARE @index_access_count int = 0; 

IF OBJECT_ID('tempdb.dbo.#sql_modules', 'U') IS NOT NULL DROP TABLE dbo.#sql_modules;
CREATE TABLE dbo.#sql_modules (id INT IDENTITY PRIMARY KEY, [procedure] sysname);

IF OBJECT_ID('tempdb.dbo.#data', 'U') IS NOT NULL DROP TABLE dbo.#data;
CREATE TABLE dbo.#data
(
	id INT IDENTITY PRIMARY KEY,
	[command] [nvarchar](791) NULL,
	[server] [nvarchar](128) NULL,
	[database] [nvarchar](128) NULL,
	[schema] [nvarchar](128) NULL,
	[object] [nvarchar](128) NULL,
	[index] [sysname] NULL,
	[size_mb] [bigint] NULL,
	[user_updates] [bigint] NOT NULL,
	[user_seeks] [bigint] NOT NULL,
	[user_scans] [bigint] NOT NULL,
	[user_lookups] [bigint] NOT NULL,
	[index_type] [varchar](12) NOT NULL,
	[is_primary_key] [bit] NULL,
	[is_unique] [varchar](3) NOT NULL,
	is_sql_modules bit NULL,
	[procedure] sysname NULL
);

INSERT dbo.#data

SELECT 
	'DROP INDEX ' + QUOTENAME(i.name) + ' ON ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + '.' + QUOTENAME(object_name(i.object_id)) + ';' command
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
	,NULL
	,NULL
FROM sys.indexes i  
INNER JOIN sys.dm_db_index_usage_stats s ON s.object_id = i.object_id AND i.index_id = s.index_id 
INNER JOIN sys.tables t ON t.object_id = i.object_id
CROSS APPLY (SELECT  p.index_id
                    ,SUM(p.rows) AS row_count
                    ,SUM(au.size_mb) AS size_mb
              FROM sys.partitions p
              INNER JOIN (SELECT  container_id
                                 ,SUM(total_pages) / 128 AS size_mb
                            FROM sys.allocation_units
                            GROUP BY container_id
						) au ON au.container_id = p.partition_id
              WHERE p.object_id = i.object_id AND p.index_id = i.index_id
              GROUP BY p.object_id , p.index_id
			) isize
WHERE OBJECTPROPERTY(i.object_id, 'IsIndexable') = 1 AND OBJECTPROPERTY(i.object_id, 'IsSystemTable') = 0 AND s.index_id > 0
--AND (s.index_id IS NULL OR (isnull(s.user_updates, 0) >= 0 AND ISNULL(s.user_seeks, 0) <= @index_access_count AND ISNULL(s.user_scans, 0) <= @index_access_count AND ISNULL(s.user_lookups, 0) <= @index_access_count ) )
AND database_id = DB_ID()
--AND i.type <> 1 
--AND i.is_primary_key <> 1
--AND i.is_unique = 0
AND object_name(i.object_id) = @table
--ORDER BY OBJECT_NAME(i.object_id) DESC, s.user_updates DESC;
--select * from #data

IF @is_check = 0 
BEGIN;
	SELECT * FROM dbo.#data
	RETURN;
END;

DECLARE @command nvarchar(max), @parm_definition nvarchar(500), @min_id int, @max_id int, @index sysname, @object sysname, @procedure sysname, @is_sql_modules bit, @is_sql_modules_out bit, @rows bigint, @min_id_sql_modules int, @max_id_sql_modules int;
SELECT @min_id = MIN(id), @max_id = MAX(id) FROM #data;

WHILE @min_id <=  @max_id
BEGIN;
	SELECT @index = [index], @object = [object] FROM dbo.#data WHERE id = @min_id;
	--PRINT '-- ' + @object + ' | ' + @index ;
	
	-- Find if the index is hard coded (index hint)
	SELECT @command = 'IF EXISTS (SELECT * FROM sys.sql_modules WHERE definition LIKE ''%' + @index + '%'') SELECT @is_sql_modules = 1 ELSE SELECT @is_sql_modules = 0;';
	SELECT @parm_definition =  N'@is_sql_modules bit OUTPUT';
	EXEC sp_executesql @command, @parm_definition, @is_sql_modules = @is_sql_modules_out OUTPUT;
	PRINT  @command;

	IF @is_sql_modules_out = 1
	BEGIN;
		--INSERT dbo.#sql_modules([procedure])
		SELECT @procedure = OBJECT_NAME(object_id) FROM sys.sql_modules WHERE definition LIKE '%' + @index + '%';
	
		UPDATE dbo.#data SET is_sql_modules = @is_sql_modules_out, [procedure] = @procedure WHERE id = @min_id;
	END;
	
	
	SELECT @is_sql_modules_out = NULL, @procedure = NULL;
	SELECT @min_id +=1;
END;

SELECT * FROM dbo.#data WHERE is_sql_modules = 1;
