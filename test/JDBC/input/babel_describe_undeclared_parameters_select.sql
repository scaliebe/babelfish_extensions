CREATE TABLE babel_dup_select_t (nummer INT PRIMARY KEY, bezeichnung VARCHAR(40), betrag NUMERIC(12,2), datum DATETIME, nname NVARCHAR(20))
GO

CREATE TABLE babel_dup_select_t2 (id INT, nummer INT)
GO

-- a parameter in the WHERE clause of a SELECT from one table
EXEC sys.sp_describe_undeclared_parameters N'select * from babel_dup_select_t where nummer=@P1 order by Nummer'
GO

EXEC sys.sp_describe_undeclared_parameters N'SELECT nummer, bezeichnung FROM dbo.babel_dup_select_t WHERE bezeichnung = @P1 AND betrag > @P2 AND datum <= @P3 AND nname = @P4'
GO

-- with a table alias
EXEC sys.sp_describe_undeclared_parameters N'SELECT t.nummer FROM babel_dup_select_t t WHERE t.bezeichnung = @P1 AND t.nummer = @P2'
GO

-- a column that does not exist
EXEC sys.sp_describe_undeclared_parameters N'SELECT nummer FROM babel_dup_select_t WHERE nosuchcolumn = @P1'
GO

-- not supported, empty result: join, no WHERE clause, UNION
EXEC sys.sp_describe_undeclared_parameters N'SELECT t.nummer FROM babel_dup_select_t t JOIN babel_dup_select_t2 t2 ON t2.nummer = t.nummer WHERE t.nummer = @P1'
GO

EXEC sys.sp_describe_undeclared_parameters N'SELECT nummer FROM babel_dup_select_t'
GO

EXEC sys.sp_describe_undeclared_parameters N'SELECT nummer FROM babel_dup_select_t WHERE nummer = @P1 UNION ALL SELECT nummer FROM babel_dup_select_t2 WHERE nummer = @P2'
GO

-- UPDATE and DELETE with a qualified column name
EXEC sys.sp_describe_undeclared_parameters N'DELETE FROM babel_dup_select_t WHERE babel_dup_select_t.nummer = @P1'
GO

EXEC sys.sp_describe_undeclared_parameters N'UPDATE babel_dup_select_t SET bezeichnung = @P1 WHERE babel_dup_select_t.nummer = @P2'
GO

DROP TABLE babel_dup_select_t2
GO

DROP TABLE babel_dup_select_t
GO
