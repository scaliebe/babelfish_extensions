-- PostgreSQL has no named default constraints. sys.default_constraints
-- synthesises a name for every column default, and ALTER TABLE ... DROP
-- CONSTRAINT with that name drops the default.
CREATE TABLE babel_drop_df_t (
    id INT NOT NULL CONSTRAINT pk_babel_drop_df PRIMARY KEY,
    a INT DEFAULT -1,
    b VARCHAR(10) CONSTRAINT df_babel_drop_df_b DEFAULT '',
    c INT,
    d DATETIME DEFAULT GETDATE()
);
GO
ALTER TABLE babel_drop_df_t ADD CONSTRAINT df_babel_drop_df_c DEFAULT 5 FOR c;
GO
-- the synthesised names carry an oid, so they are looked up rather than printed
SELECT c.name AS column_name, dc.definition, CASE WHEN dc.name LIKE 'DF[_]babel[_]drop[_]df[_]t[_]%' THEN 'synthesised' ELSE dc.name END AS name_kind
FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') ORDER BY c.column_id;
GO

-- drop by the name sys.default_constraints reports
DECLARE @n sysname = (SELECT dc.name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') AND c.name = 'a');
EXEC('ALTER TABLE dbo.babel_drop_df_t DROP CONSTRAINT ' + @n);
GO
-- bracketed and in upper case
DECLARE @n sysname = (SELECT dc.name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') AND c.name = 'c');
SET @n = UPPER(@n);
EXEC('ALTER TABLE babel_drop_df_t DROP CONSTRAINT [' + @n + ']');
GO
-- IF EXISTS, twice: the second one is a no-op
DECLARE @n sysname = (SELECT dc.name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') AND c.name = 'd');
EXEC('ALTER TABLE babel_drop_df_t DROP CONSTRAINT IF EXISTS ' + @n);
EXEC('ALTER TABLE babel_drop_df_t DROP CONSTRAINT IF EXISTS ' + @n);
GO
SELECT c.name AS column_name, dc.definition
FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') ORDER BY c.column_id;
GO
INSERT INTO babel_drop_df_t (id) VALUES (1);
GO
SELECT id, a, b, c, d FROM babel_drop_df_t;
GO

-- a synthesised name of another table's default is not accepted for this table
CREATE TABLE babel_drop_df_t2 (x INT DEFAULT 1);
GO
DECLARE @n sysname = (SELECT dc.name FROM sys.default_constraints dc WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t2'));
BEGIN TRY
    EXEC('ALTER TABLE babel_drop_df_t DROP CONSTRAINT ' + @n);
    SELECT 'accepted' AS result;
END TRY
BEGIN CATCH
    -- the message carries the oid-based name, so only the error number is shown
    SELECT ERROR_NUMBER() AS error_number;
END CATCH
GO
SELECT COUNT(*) AS t2_defaults FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('babel_drop_df_t2');
GO
-- unknown names, a malformed synthesised name, and the name given at creation (not preserved)
ALTER TABLE babel_drop_df_t DROP CONSTRAINT DF_babel_drop_df_t_999999999;
GO
ALTER TABLE babel_drop_df_t DROP CONSTRAINT DF_babel_drop_df_t_x;
GO
ALTER TABLE babel_drop_df_t DROP CONSTRAINT df_babel_drop_df_b;
GO
-- real constraints are still dropped by name
ALTER TABLE babel_drop_df_t DROP CONSTRAINT pk_babel_drop_df;
GO
SELECT COUNT(*) AS pk_count FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('babel_drop_df_t');
GO

-- in a procedure, as application upgrade scripts do it
CREATE PROCEDURE babel_drop_df_p @col sysname AS
BEGIN
    DECLARE @n sysname = (SELECT dc.name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t') AND c.name = @col);
    IF @n IS NOT NULL EXEC('ALTER TABLE babel_drop_df_t DROP CONSTRAINT ' + @n);
END
GO
EXEC babel_drop_df_p 'b';
GO
SELECT c.name AS column_name FROM sys.default_constraints dc JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID('babel_drop_df_t');
GO

DROP PROCEDURE babel_drop_df_p;
DROP TABLE babel_drop_df_t2;
DROP TABLE babel_drop_df_t;
GO
