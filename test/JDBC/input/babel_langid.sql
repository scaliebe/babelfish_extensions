-- @@LANGID is the id of the session language in sys.syslanguages. Babelfish
-- numbers its languages itself, so the id is looked up by the name that
-- @@LANGUAGE reports.
SELECT @@LANGID AS langid, @@LANGUAGE AS language;
GO
SELECT sys.langid() AS langid;
GO
SELECT CASE WHEN @@LANGID = (SELECT langid FROM sys.syslanguages WHERE name = @@LANGUAGE) THEN 'consistent' ELSE 'inconsistent' END AS langid_check;
GO

-- the query client libraries run to resolve the session language
SELECT lcid, alias FROM sys.syslanguages WHERE langid = @@Langid;
GO

-- variables, defaults, procedures
DECLARE @l SMALLINT = @@LANGID;
SELECT @l AS from_variable, CASE WHEN @l = @@langid THEN 1 ELSE 0 END AS same;
GO
CREATE TABLE babel_langid_t (id INT, lang SMALLINT DEFAULT @@LANGID);
INSERT INTO babel_langid_t (id) VALUES (1);
SELECT id, CASE WHEN lang = @@LANGID THEN 'default applied' ELSE 'wrong' END AS lang FROM babel_langid_t;
DROP TABLE babel_langid_t;
GO
CREATE PROCEDURE babel_langid_p AS SELECT @@LANGID AS langid, (SELECT name FROM sys.syslanguages WHERE langid = @@LANGID) AS name;
GO
EXEC babel_langid_p;
GO
DROP PROCEDURE babel_langid_p;
GO

-- locale ids of the languages SQL Server ships; Babelfish-only entries keep NULL
SELECT langid, alias, lcid, msglangid FROM sys.syslanguages WHERE lcid IS NOT NULL ORDER BY langid;
GO
SELECT COUNT(*) AS without_lcid FROM sys.syslanguages WHERE lcid IS NULL;
GO
