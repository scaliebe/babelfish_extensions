-- ALTER TABLE ... ALTER COLUMN ... COLLATE, as issued by application upgrade scripts
CREATE TABLE babel_alter_col_coll_t (
    id INT NOT NULL,
    c_varchar VARCHAR(50) COLLATE Latin1_General_CS_AS NOT NULL,
    c_nvarchar NVARCHAR(50) COLLATE Latin1_General_CI_AS,
    c_text TEXT COLLATE Latin1_General_CS_AS,
    c_char CHAR(10) COLLATE Latin1_General_CI_AS,
    c_xml XML
);
GO
INSERT INTO babel_alter_col_coll_t (id, c_varchar, c_nvarchar, c_text, c_char) VALUES (1, N'Äpfel', N'Äpfel', N'Äpfel', N'Äpfel'), (2, N'apfel', N'apfel', N'apfel', N'apfel'), (3, N'APFEL', N'APFEL', N'APFEL', N'APFEL');
GO
SELECT name, collation_name, max_length, is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') ORDER BY column_id;
GO

-- the statement an application upgrade issued: TEXT with COLLATE and an explicit NULL
ALTER TABLE dbo.babel_alter_col_coll_t ALTER COLUMN c_text TEXT COLLATE Latin1_General_CI_AS NULL;
GO
-- collation change with explicit nullability and unchanged type and length
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_varchar VARCHAR(50) COLLATE Latin1_General_CI_AS NOT NULL;
GO
-- collation change together with a length change
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_nvarchar NVARCHAR(100) COLLATE Latin1_General_CS_AS NULL;
GO
-- collation change without a nullability clause
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_char CHAR(10) COLLATE SQL_Latin1_General_CP1_CS_AS;
GO
SELECT name, collation_name, max_length, is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') ORDER BY column_id;
GO
SELECT COLUMN_NAME, COLLATION_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'babel_alter_col_coll_t' ORDER BY ORDINAL_POSITION;
GO

-- data is preserved and the new collations are in effect
SELECT id, c_varchar, c_nvarchar, CAST(c_text AS NVARCHAR(50)) AS c_text, c_char FROM babel_alter_col_coll_t ORDER BY id;
GO
SELECT id FROM babel_alter_col_coll_t WHERE c_varchar = 'apfel' ORDER BY id;
GO
SELECT id FROM babel_alter_col_coll_t WHERE c_nvarchar = N'apfel' ORDER BY id;
GO
SELECT id FROM babel_alter_col_coll_t WHERE c_text LIKE 'apfel' ORDER BY id;
GO
SELECT id FROM babel_alter_col_coll_t WHERE c_char = 'apfel' ORDER BY id;
GO

-- nullability-only changes keep the collation
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_nvarchar NVARCHAR(100) NOT NULL;
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_nvarchar NVARCHAR(100) NULL;
GO
SELECT name, collation_name, is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name = 'c_nvarchar';
GO

-- database_default (reported relative to the database collation so the output does not depend on it), an indexed column, TEXT and XML types without COLLATE
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_char CHAR(10) COLLATE database_default NULL;
GO
SELECT name, CASE WHEN collation_name = CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS VARCHAR(128)) THEN '<database default>' ELSE collation_name END AS collation_name FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name = 'c_char';
GO
CREATE INDEX babel_alter_col_coll_ix ON babel_alter_col_coll_t (c_varchar);
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_varchar VARCHAR(50) COLLATE Latin1_General_CS_AS NOT NULL;
GO
SELECT id FROM babel_alter_col_coll_t WHERE c_varchar = 'apfel' ORDER BY id;
GO
SELECT name FROM sys.indexes WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name = 'babel_alter_col_coll_ix';
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_text TEXT NOT NULL;
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_xml XML NULL;
GO
SELECT name, CASE WHEN collation_name = CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS VARCHAR(128)) THEN '<database default>' ELSE collation_name END AS collation_name, is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name IN ('c_char', 'c_text', 'c_xml') ORDER BY column_id;
GO

-- in a procedure and via dynamic SQL
CREATE PROCEDURE babel_alter_col_coll_p AS ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_nvarchar NVARCHAR(100) COLLATE Latin1_General_CI_AI NULL;
GO
EXEC babel_alter_col_coll_p;
GO
EXEC sp_executesql N'ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_char CHAR(10) COLLATE Latin1_General_CI_AS NULL';
GO
SELECT name, collation_name FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name IN ('c_nvarchar', 'c_char') ORDER BY column_id;
GO

-- unknown collation, and a collation on a non-character column, with and without a nullability clause
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_varchar VARCHAR(50) COLLATE No_Such_Collation NULL;
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN c_varchar VARCHAR(50) COLLATE No_Such_Collation;
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN id INT COLLATE Latin1_General_CI_AS NOT NULL;
GO
ALTER TABLE babel_alter_col_coll_t ALTER COLUMN id INT COLLATE Latin1_General_CI_AS;
GO
SELECT name, collation_name, is_nullable FROM sys.columns WHERE object_id = OBJECT_ID('babel_alter_col_coll_t') AND name IN ('id', 'c_varchar') ORDER BY column_id;
GO

DROP PROCEDURE babel_alter_col_coll_p;
DROP TABLE babel_alter_col_coll_t;
GO
