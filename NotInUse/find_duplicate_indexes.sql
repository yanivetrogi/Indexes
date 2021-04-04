USE AdventureWorks2017
;WITH CTE_INDEX_DATA
AS (SELECT 
		  s.name AS schema_name
          ,t.name  AS table_name
          ,i.name  AS index_name
          ,STUFF(
           (
             SELECT ', ' + COLUMN_DATA_KEY_COLS.name + ' '
                    + CASE WHEN INDEX_COLUMN_DATA_KEY_COLS.is_descending_key = 1 THEN 'DESC' ELSE 'ASC' END -- Include column order (ASC / DESC)

             FROM sys.tables              AS T
             INNER JOIN sys.indexes       INDEX_DATA_KEY_COLS ON T.object_id = INDEX_DATA_KEY_COLS.object_id 
			 INNER JOIN sys.index_columns INDEX_COLUMN_DATA_KEY_COLS ON INDEX_DATA_KEY_COLS.object_id = INDEX_COLUMN_DATA_KEY_COLS.object_id AND INDEX_DATA_KEY_COLS.index_id = INDEX_COLUMN_DATA_KEY_COLS.index_id
             INNER JOIN sys.columns       COLUMN_DATA_KEY_COLS ON T.object_id = COLUMN_DATA_KEY_COLS.object_id AND INDEX_COLUMN_DATA_KEY_COLS.column_id = COLUMN_DATA_KEY_COLS.column_id
             WHERE i.object_id = INDEX_DATA_KEY_COLS.object_id
                   AND i.index_id = INDEX_DATA_KEY_COLS.index_id
                   AND INDEX_COLUMN_DATA_KEY_COLS.is_included_column = 0
             ORDER BY INDEX_COLUMN_DATA_KEY_COLS.key_ordinal
             FOR XML PATH('')
           )
          ,1
          ,2
          ,''
                )           AS keys
          ,STUFF(
           (
             SELECT ', ' + COLUMN_DATA_INC_COLS.name
             FROM sys.tables              AS T
             INNER JOIN sys.indexes       INDEX_DATA_INC_COLS ON T.object_id = INDEX_DATA_INC_COLS.object_id
             INNER JOIN sys.index_columns INDEX_COLUMN_DATA_INC_COLS ON INDEX_DATA_INC_COLS.object_id = INDEX_COLUMN_DATA_INC_COLS.object_id AND INDEX_DATA_INC_COLS.index_id = INDEX_COLUMN_DATA_INC_COLS.index_id
             INNER JOIN sys.columns       COLUMN_DATA_INC_COLS ON T.object_id = COLUMN_DATA_INC_COLS.object_id AND INDEX_COLUMN_DATA_INC_COLS.column_id = COLUMN_DATA_INC_COLS.column_id
             WHERE i.object_id = INDEX_DATA_INC_COLS.object_id
                   AND i.index_id = INDEX_DATA_INC_COLS.index_id
                   AND INDEX_COLUMN_DATA_INC_COLS.is_included_column = 1
             ORDER BY INDEX_COLUMN_DATA_INC_COLS.key_ordinal
             FOR XML PATH('')
           )
          ,1
          ,2
          ,''
                )           AS include_columns
		  ,i.is_unique
		  ,i.is_primary_key
		  ,i.index_id
		  ,i.is_disabled 
		  ,'EXEC sp_helpindex2 @table = ''' + t.name + ''', @schema = ''' + s.name + '''' as sp_helpindex2
    FROM sys.indexes i
    INNER JOIN sys.tables  t ON t.object_id = i.object_id
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
	--INNER JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id
	--INNER JOIN sys.allocation_units au ON au.container_id = p.partition_id
	--INNER JOIN sys.filegroups g ON g.data_space_id = au.data_space_id 
    WHERE t.is_ms_shipped = 0 AND i.type_desc IN ('NONCLUSTERED', 'CLUSTERED'))

SELECT *
FROM CTE_INDEX_DATA DUPE1
WHERE EXISTS
(
  SELECT *
  FROM CTE_INDEX_DATA DUPE2
  WHERE DUPE1.schema_name = DUPE2.schema_name AND DUPE1.table_name = DUPE2.table_name
        AND
        (
          DUPE1.keys LIKE LEFT(DUPE2.keys, LEN(DUPE1.keys))
          OR DUPE2.keys LIKE LEFT(DUPE1.keys, LEN(DUPE2.keys))
        ) AND DUPE1.index_name <> DUPE2.index_name
);