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

SET NO_BROWSETABLE OFF
GO

DROP TABLE babel_no_browsetable_t2
GO

DROP TABLE babel_no_browsetable_t1
GO
