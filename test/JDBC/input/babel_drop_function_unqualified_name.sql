-- DROP FUNCTION / DROP PROCEDURE without schema name for a user routine
-- whose name matches an overloaded system function
CREATE FUNCTION dbo.concat (@str1 VARCHAR(100), @str2 VARCHAR(100)) RETURNS VARCHAR(200) AS
BEGIN
    RETURN ISNULL(@str1, '') + ISNULL(@str2, '')
END
GO

SELECT dbo.concat('abc', NULL), CONCAT('abc', NULL, 'def')
GO

DROP FUNCTION concat
GO

SELECT OBJECT_ID('dbo.concat')
GO

-- the system function is still there and cannot be dropped this way
SELECT CONCAT('abc', 'def')
GO

DROP FUNCTION concat
GO

-- IF EXISTS
CREATE FUNCTION dbo.replicate (@a INT) RETURNS INT AS
BEGIN
    RETURN @a
END
GO

DROP FUNCTION IF EXISTS replicate
GO

SELECT OBJECT_ID('dbo.replicate'), REPLICATE('ab', 2)
GO

-- procedure
CREATE PROCEDURE dbo.babel_drop_function_unq_p1 AS SELECT 1
GO

DROP PROCEDURE babel_drop_function_unq_p1
GO

SELECT COUNT(*) FROM sys.objects WHERE name = 'babel_drop_function_unq_p1'
GO

DROP PROCEDURE babel_drop_function_unq_p1
GO

-- a routine of the same name in another schema is not affected
CREATE SCHEMA babel_drop_function_unq_s1
GO

CREATE FUNCTION babel_drop_function_unq_s1.concat (@a INT) RETURNS INT AS
BEGIN
    RETURN @a
END
GO

DROP FUNCTION concat
GO

SELECT babel_drop_function_unq_s1.concat(1)
GO

DROP FUNCTION babel_drop_function_unq_s1.concat
GO

DROP SCHEMA babel_drop_function_unq_s1
GO
