USE AdventureWorks;


DROP TABLE #candidates;
DROP TABLE #planops;
DROP TABLE #indexusage;

SELECT d.[object_id]
      ,s = OBJECT_SCHEMA_NAME(d.[object_id])
      ,o = OBJECT_NAME(d.[object_id])
      ,d.equality_columns
      ,d.inequality_columns
      ,d.included_columns
      ,s.unique_compiles
      ,s.user_seeks
      ,s.last_user_seek
      ,s.user_scans
      ,s.last_user_scan
INTO #candidates
FROM sys.dm_db_missing_index_details           AS d
INNER JOIN sys.dm_db_missing_index_groups      AS g ON d.index_handle = g.index_handle
INNER JOIN sys.dm_db_missing_index_group_stats AS s ON g.index_group_handle = s.group_handle
WHERE d.database_id = DB_ID() AND OBJECTPROPERTY(d.[object_id], 'IsMsShipped') = 0;

--SELECT * FROM #candidates


CREATE TABLE #planops
(
  o int
 ,i int
 ,h varbinary(64)
 ,uc int
 ,Scan_Ops int
 ,Seek_Ops int
 ,Update_Ops int
);

;WITH XMLNAMESPACES
(
  DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
)
INSERT #planops
SELECT o
      ,i
      ,h
      ,uc
      ,Scan_Ops
      ,Seek_Ops
      ,Update_Ops
FROM
(
  SELECT o          = i.object_id
        ,i          = i.index_id
        ,h          = pl.plan_handle
        ,uc         = pl.usecounts
        ,Scan_Ops   = p.query_plan.value('count(//RelOp[@LogicalOp = ("Index Scan", "Clustered Index Scan")]/*/Object[@Index = sql:column("i2.name")])', 'int')
        ,Seek_Ops   = p.query_plan.value('count(//RelOp[@LogicalOp = ("Index Seek", "Clustered Index Seek")]/*/Object[@Index = sql:column("i2.name")])', 'int')
        ,Update_Ops = p.query_plan.value('count(//Update/Object[@Index = sql:column("i2.name")])', 'int')
  FROM sys.indexes                   AS i
  CROSS APPLY
  (SELECT QUOTENAME(i.name) AS name) AS i2
  CROSS APPLY sys.dm_exec_cached_plans AS pl
  CROSS APPLY sys.dm_exec_query_plan(pl.plan_handle) AS p
  WHERE EXISTS
  (
    SELECT 1 FROM #candidates AS c WHERE c.[object_id] = i.[object_id]
  )
        AND p.query_plan.exist('//Object[@Index = sql:column("i2.name")]') = 1
        AND p.[dbid] = DB_ID()
        AND i.index_id > 0
) AS T
WHERE Scan_Ops + Seek_Ops + Update_Ops > 0;

SELECT * FROM #planops;


SELECT [object_id]
      ,index_id
      ,user_seeks
      ,user_scans
      ,user_lookups
      ,user_updates
INTO #indexusage
FROM sys.dm_db_index_usage_stats AS s
WHERE database_id = DB_ID()
AND EXISTS (SELECT 1 FROM #candidates WHERE [object_id] = s.[object_id] );

SELECT * FROM #indexusage;

;WITH x
AS (SELECT c.[object_id]
          ,potential_read_ops     = SUM(c.user_seeks + c.user_scans)
          ,[write_ops]            = SUM(iu.user_updates)
          ,[read_ops]             = SUM(iu.user_scans + iu.user_seeks + iu.user_lookups)
          ,[write:read ratio]     = CONVERT(decimal(18, 2), SUM(iu.user_updates) * 1.0 / SUM(iu.user_scans + iu.user_seeks + iu.user_lookups))
          ,current_plan_count     = po.h
          ,current_plan_use_count = po.uc
    FROM #candidates                                                AS c
    LEFT OUTER JOIN #indexusage                                     AS iu ON c.[object_id] = iu.[object_id]
    LEFT OUTER JOIN
    (SELECT o, h = COUNT(h), uc = SUM(uc) FROM #planops GROUP BY o) AS po ON c.[object_id] = po.o
    GROUP BY c.[object_id]
            ,po.h
            ,po.uc)
SELECT [object] = QUOTENAME(c.s) + '.' + QUOTENAME(c.o)
      ,c.equality_columns
      ,c.inequality_columns
      ,c.included_columns
      ,x.potential_read_ops
      ,x.write_ops
      ,x.read_ops
      ,x.[write:read ratio]
      ,x.current_plan_count
      ,x.current_plan_use_count
FROM #candidates AS c
INNER JOIN x ON c.[object_id] = x.[object_id]
ORDER BY x.[write:read ratio];