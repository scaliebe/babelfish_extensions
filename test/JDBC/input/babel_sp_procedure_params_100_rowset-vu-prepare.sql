CREATE PROCEDURE babel_sp_proc_params_rowset_p1 @a INT, @b VARCHAR(20) = 'x', @c NVARCHAR(MAX) OUTPUT, @d DECIMAL(10,2) = 1.5, @e DATETIME, @f BIT, @g UNIQUEIDENTIFIER, @h VARBINARY(50), @i DATETIME2(3), @j BIGINT, @k MONEY, @l CHAR(5), @m DATE, @n TIME(2), @o SMALLINT, @p TINYINT, @q FLOAT, @r REAL, @s SMALLDATETIME, @t DATETIMEOFFSET(4), @u NCHAR(4), @v XML, @w SQL_VARIANT, @x NUMERIC(18,0), @y TEXT, @z NTEXT, @aa IMAGE, @ab SMALLMONEY, @ac VARCHAR(MAX), @ad VARBINARY(MAX) AS SELECT 1
GO

CREATE FUNCTION babel_sp_proc_params_rowset_f1 (@a INT) RETURNS VARCHAR(10) AS BEGIN RETURN 'x' END
GO

CREATE SCHEMA babel_sp_proc_params_rowset_s1
GO

CREATE PROCEDURE babel_sp_proc_params_rowset_s1.babel_sp_proc_params_rowset_p1 @other NVARCHAR(10) AS SELECT 1
GO
