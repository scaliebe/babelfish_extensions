-- With SET NO_BROWSETABLE ON the TABNAME and COLINFO tokens are sent with the
-- result. The driver of this test ignores them; the results have to be the
-- same as without the setting.
CREATE TABLE babel_no_browsetable_t1 (TerminalNr INT NOT NULL PRIMARY KEY, Name VARCHAR(30), Typ INT)
GO

CREATE TABLE babel_no_browsetable_t2 (TermTypID INT NOT NULL PRIMARY KEY, HerstellerID INT)
GO

INSERT INTO babel_no_browsetable_t1 VALUES (1, 'T1', 7), (2, 'T2', NULL)
GO

INSERT INTO babel_no_browsetable_t2 VALUES (7, 99)
GO

SET NO_BROWSETABLE ON
GO

SELECT t.*, tp.HerstellerID FROM babel_no_browsetable_t1 t LEFT JOIN babel_no_browsetable_t2 tp ON tp.TermTypID = t.Typ WHERE TerminalNr = 1 ORDER BY TerminalNr
GO

SELECT Name, Name + 'x' AS expr, Name AS other_name, TerminalNr AS terminalnr FROM babel_no_browsetable_t1 ORDER BY TerminalNr
GO

SELECT 1 AS no_table
GO

SELECT COUNT(*) AS cnt FROM babel_no_browsetable_t1
GO

SELECT name FROM sys.objects WHERE name = 'babel_no_browsetable_t1'
GO

UPDATE babel_no_browsetable_t1 SET Name = 'T1a' WHERE TerminalNr = 1
GO

SELECT * FROM babel_no_browsetable_t1 ORDER BY TerminalNr
GO

-- the table names are sent like the statement writes them: one, two or
-- three parts, delimited, in any case, in a join, a subquery and a CTE. The
-- key columns are selected, so that the result is the same if the server
-- adds the key columns that a statement does not select.
CREATE TABLE babel_no_browsetable_t3 (a INT NOT NULL PRIMARY KEY, b TEXT, [c d] NTEXT)
GO

INSERT INTO babel_no_browsetable_t3 VALUES (1, 'x', N'y')
GO

SELECT a, b FROM babel_no_browsetable_t3
GO

SELECT a, b FROM dbo.babel_no_browsetable_t3
GO

SELECT a, b FROM master.dbo.babel_no_browsetable_t3
GO

SELECT a, b FROM master..babel_no_browsetable_t3
GO

SELECT a, b, [c d] FROM [dbo].[babel_no_browsetable_t3]
GO

SELECT a, b FROM "dbo"."babel_no_browsetable_t3"
GO

SELECT x.a, x.b FROM DBO.BABEL_NO_BROWSETABLE_T3 x
GO

SELECT t.a, t.b, u.TerminalNr, u.Name FROM babel_no_browsetable_t3 t JOIN dbo.babel_no_browsetable_t1 u ON u.TerminalNr = t.a
GO

SELECT s.a, s.b FROM (SELECT a, b FROM dbo.babel_no_browsetable_t3) s
GO

WITH c AS (SELECT a, b FROM babel_no_browsetable_t3) SELECT c.a, c.b, u.TerminalNr, u.Name FROM c, [babel_no_browsetable_t1] u WHERE u.TerminalNr = c.a
GO

SELECT a, b FROM babel_no_browsetable_t3 UNION ALL SELECT a, b FROM dbo.babel_no_browsetable_t3
GO

EXEC sp_executesql N'SELECT a, b FROM babel_no_browsetable_t3 WHERE a = @P1', N'@P1 INT', 1
GO

UPDATE babel_no_browsetable_t3 SET b = 'z' OUTPUT deleted.b, inserted.b WHERE a = 1
GO

SET NO_BROWSETABLE OFF
GO

-- a temporary table, also after the connection was reset: its schema has no
-- name then
CREATE TABLE #babel_no_browsetable_tmp (a INT NOT NULL PRIMARY KEY, b TEXT)
GO

INSERT INTO #babel_no_browsetable_tmp VALUES (1, 'x')
GO

SET NO_BROWSETABLE ON
GO

SELECT * FROM #babel_no_browsetable_tmp
GO

DROP TABLE #babel_no_browsetable_tmp
GO

EXEC sys.sp_reset_connection
GO

CREATE TABLE #babel_no_browsetable_tmp (a INT NOT NULL PRIMARY KEY, b TEXT)
GO

INSERT INTO #babel_no_browsetable_tmp VALUES (1, 'x')
GO

SET NO_BROWSETABLE ON
GO

SELECT * FROM #babel_no_browsetable_tmp
GO

SELECT a, b FROM #babel_no_browsetable_tmp WHERE a = 1
GO

DROP TABLE #babel_no_browsetable_tmp
GO

SET NO_BROWSETABLE OFF
GO

-- a column of a large object type carries the table name without the setting
SELECT a, b FROM babel_no_browsetable_t3
GO

SELECT a, b, [c d] FROM [dbo].[babel_no_browsetable_t3]
GO

DROP TABLE babel_no_browsetable_t3
GO

DROP TABLE babel_no_browsetable_t2
GO

DROP TABLE babel_no_browsetable_t1
GO
