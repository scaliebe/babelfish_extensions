-- The call of a T-SQL function carries the length, precision and scale of
-- its return type, so a view column defined with it has them too.
CREATE FUNCTION dbo.babel_udf_rt_v (@n INT) RETURNS VARCHAR(255) AS BEGIN RETURN 'Test' END
GO

CREATE FUNCTION dbo.babel_udf_rt_n (@n INT) RETURNS NVARCHAR(40) AS BEGIN RETURN N'Test' END
GO

CREATE FUNCTION dbo.babel_udf_rt_d (@n INT) RETURNS DECIMAL(10,2) AS BEGIN RETURN 1.5 END
GO

CREATE FUNCTION dbo.babel_udf_rt_c (@n INT) RETURNS CHAR(5) AS BEGIN RETURN 'ab' END
GO

CREATE FUNCTION dbo.babel_udf_rt_max (@n INT) RETURNS VARCHAR(MAX) AS BEGIN RETURN 'ab' END
GO

CREATE FUNCTION dbo.babel_udf_rt_i (@n INT) RETURNS INT AS BEGIN RETURN @n + 1 END
GO

CREATE FUNCTION dbo.babel_udf_rt_def (@n INT, @s VARCHAR(10) = 'x') RETURNS VARCHAR(20) AS BEGIN RETURN @s END
GO

CREATE FUNCTION dbo.babel_udf_rt_long (@n INT) RETURNS VARCHAR(10) AS BEGIN RETURN 'abcdefghijklmnop' END
GO

CREATE TABLE babel_udf_rt_t (id INT, name VARCHAR(30))
GO

INSERT INTO babel_udf_rt_t VALUES (1, 'one'), (2, 'two')
GO

CREATE VIEW babel_udf_rt_view AS
SELECT dbo.babel_udf_rt_v(id) AS wert, dbo.babel_udf_rt_n(id) AS n, dbo.babel_udf_rt_d(id) AS d, dbo.babel_udf_rt_c(id) AS c,
       dbo.babel_udf_rt_max(id) AS m, dbo.babel_udf_rt_i(id) AS i, dbo.babel_udf_rt_def(id, DEFAULT) AS def, dbo.babel_udf_rt_long(id) AS lng,
       dbo.babel_udf_rt_v(id) + 'x' AS wx, UPPER(dbo.babel_udf_rt_v(id)) AS wu, dbo.babel_udf_rt_v(id) + name AS wn
FROM babel_udf_rt_t
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length, precision, scale
FROM sys.columns WHERE object_id = OBJECT_ID('babel_udf_rt_view') ORDER BY column_id
GO

SELECT wert, n, d, c, m, i, def, lng, wx, wu, wn FROM babel_udf_rt_view ORDER BY i
GO

EXEC sp_describe_first_result_set N'SELECT dbo.babel_udf_rt_v(1) AS wert, dbo.babel_udf_rt_d(1) AS d'
GO

-- in a condition, in ORDER BY and GROUP BY, in an assignment and as an argument
SELECT dbo.babel_udf_rt_v(id) AS w, COUNT(*) AS cnt FROM babel_udf_rt_t WHERE dbo.babel_udf_rt_v(id) = 'Test' GROUP BY dbo.babel_udf_rt_v(id) ORDER BY dbo.babel_udf_rt_v(id)
GO

DECLARE @v VARCHAR(5) = dbo.babel_udf_rt_long(1)
SELECT @v AS v, LEN(dbo.babel_udf_rt_long(1)) AS l, dbo.babel_udf_rt_i(dbo.babel_udf_rt_i(1)) AS nested
GO

-- SELECT INTO keeps the length
SELECT dbo.babel_udf_rt_v(id) AS wert, dbo.babel_udf_rt_d(id) AS d INTO babel_udf_rt_t2 FROM babel_udf_rt_t
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length, precision, scale
FROM sys.columns WHERE object_id = OBJECT_ID('babel_udf_rt_t2') ORDER BY column_id
GO

DROP TABLE babel_udf_rt_t2
GO

DROP VIEW babel_udf_rt_view
GO

DROP TABLE babel_udf_rt_t
GO

DROP FUNCTION dbo.babel_udf_rt_v, dbo.babel_udf_rt_n, dbo.babel_udf_rt_d, dbo.babel_udf_rt_c, dbo.babel_udf_rt_max, dbo.babel_udf_rt_i, dbo.babel_udf_rt_def, dbo.babel_udf_rt_long
GO
