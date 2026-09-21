-- A scalar user-defined function can only be called with its schema name in
-- T-SQL. A call without schema name is the built-in function, also if a
-- user-defined function of that name exists.
CREATE FUNCTION dbo.concat (@a VARCHAR(8000), @b VARCHAR(8000)) RETURNS VARCHAR(8000) AS BEGIN RETURN 'udf:' + ISNULL(@a, '') + ISNULL(@b, '') END
GO

CREATE FUNCTION dbo.replicate (@a VARCHAR(100), @n INT) RETURNS VARCHAR(100) AS BEGIN RETURN 'udf' END
GO

CREATE FUNCTION dbo.babel_builtin_over_udf_f (@a INT) RETURNS INT AS BEGIN RETURN @a + 1 END
GO

CREATE TABLE babel_builtin_over_udf_t (name VARCHAR(50), code VARCHAR(3))
GO

INSERT INTO babel_builtin_over_udf_t VALUES ('Test', 'ab')
GO

SELECT CONCAT(name, code) AS two_columns, CONCAT(name, ' [x]') AS column_literal, CONCAT('a', 'b') AS two_literals, CONCAT(name, code, 'c') AS three_args,
       REPLICATE(code, 2) AS repl FROM babel_builtin_over_udf_t
GO

-- with the schema name it is the function of the user
SELECT dbo.concat(name, code) AS udf, dbo.replicate(code, 2) AS udf_repl FROM babel_builtin_over_udf_t
GO

-- a user-defined function whose name is not a built-in function can still be
-- called without the schema name
SELECT dbo.babel_builtin_over_udf_f(1) AS qualified, babel_builtin_over_udf_f(1) AS unqualified
GO

-- in a view
CREATE VIEW babel_builtin_over_udf_v AS
SELECT CASE WHEN code = 'ab' THEN CONCAT(name, ' [inactive]') ELSE name END AS leader, CONCAT(name, code) AS nc FROM babel_builtin_over_udf_t
GO

SELECT leader, nc FROM babel_builtin_over_udf_v
GO

-- in a procedure, in SET and in a condition
CREATE PROCEDURE babel_builtin_over_udf_p AS
BEGIN
    DECLARE @x VARCHAR(20)
    SET @x = CONCAT('a', 'b')
    IF CONCAT('a', 'b') = 'ab'
        SELECT @x AS in_procedure, (SELECT CONCAT(name, code) FROM babel_builtin_over_udf_t) AS in_subquery
    UPDATE babel_builtin_over_udf_t SET name = CONCAT(name, code) WHERE CONCAT(name, code) = 'Testab'
    SELECT name FROM babel_builtin_over_udf_t
END
GO

EXEC babel_builtin_over_udf_p
GO

DROP PROCEDURE babel_builtin_over_udf_p
GO

DROP VIEW babel_builtin_over_udf_v
GO

DROP TABLE babel_builtin_over_udf_t
GO

DROP FUNCTION dbo.babel_builtin_over_udf_f
GO

DROP FUNCTION dbo.replicate
GO

DROP FUNCTION dbo.concat
GO
