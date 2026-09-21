-- FETCH ... INTO a variable that is shorter than the value truncates the
-- value like SET and SELECT @var = ... do
DECLARE @v VARCHAR(30)
DECLARE c CURSOR FOR SELECT CAST('12345678901234567890123456789012345' AS VARCHAR(35))
OPEN c
FETCH NEXT FROM c INTO @v
SELECT @v AS v, LEN(@v) AS l
CLOSE c
DEALLOCATE c
GO

CREATE TABLE babel_cursor_fetch_trunc_t (id INT, name VARCHAR(40), nname NVARCHAR(40), fixed CHAR(10), bin VARBINARY(10))
GO

INSERT INTO babel_cursor_fetch_trunc_t VALUES (1, 'abcdefghijklmnopqrstuvwxyz', N'abcdefghijklmnopqrstuvwxyz', 'abcdefghij', 0x0102030405060708),
                                              (2, 'short', N'short', 'ab', 0x01), (3, NULL, NULL, NULL, NULL)
GO

DECLARE @id INT, @v VARCHAR(5), @n NVARCHAR(7), @c CHAR(3), @b VARBINARY(4)
DECLARE c CURSOR FOR SELECT id, name, nname, fixed, bin FROM babel_cursor_fetch_trunc_t ORDER BY id
OPEN c
FETCH NEXT FROM c INTO @id, @v, @n, @c, @b
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @id AS id, @v AS v, @n AS n, @c AS c, @b AS b
    FETCH NEXT FROM c INTO @id, @v, @n, @c, @b
END
CLOSE c
DEALLOCATE c
GO

-- in a procedure, with a scroll cursor
CREATE PROCEDURE babel_cursor_fetch_trunc_p AS
BEGIN
    DECLARE @v VARCHAR(30), @result VARCHAR(200) = ''
    DECLARE c2 CURSOR SCROLL FOR SELECT name + ' and a long text to get over the limit' FROM babel_cursor_fetch_trunc_t WHERE name IS NOT NULL ORDER BY id
    OPEN c2
    FETCH LAST FROM c2 INTO @v
    SET @result = @v
    FETCH FIRST FROM c2 INTO @v
    SET @result = @result + '|' + @v
    CLOSE c2
    DEALLOCATE c2
    SELECT @result AS result
END
GO

EXEC babel_cursor_fetch_trunc_p
GO

-- a value that does not fit into a number is still an error
DECLARE @t TINYINT
DECLARE c CURSOR FOR SELECT 1000
OPEN c
FETCH NEXT FROM c INTO @t
CLOSE c
DEALLOCATE c
GO

-- an INSERT of a value that is too long is still an error
CREATE TABLE babel_cursor_fetch_trunc_t2 (v VARCHAR(5))
GO

INSERT INTO babel_cursor_fetch_trunc_t2 VALUES ('abcdefgh')
GO

DROP TABLE babel_cursor_fetch_trunc_t2
GO

DROP PROCEDURE babel_cursor_fetch_trunc_p
GO

DROP TABLE babel_cursor_fetch_trunc_t
GO
