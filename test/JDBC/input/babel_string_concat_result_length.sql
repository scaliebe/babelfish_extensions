-- The result of varchar(n) + varchar(m) is varchar(n + m), limited to 8000
-- (4000 for nvarchar). With a (max) operand it stays (max).
CREATE TABLE babel_string_concat_len_t1 (name VARCHAR(30), code VARCHAR(3), nname NVARCHAR(10), fixed CHAR(5), big VARCHAR(MAX), nbig NVARCHAR(MAX), v5000 VARCHAR(5000), n3000 NVARCHAR(3000), id INT)
GO

INSERT INTO babel_string_concat_len_t1 VALUES ('Deutschland', 'DE', N'xy', 'ab', 'big', N'nbig', REPLICATE('a', 5000), REPLICATE(N'b', 3000), 1)
GO

CREATE VIEW babel_string_concat_len_v1 AS
SELECT code + ' ' + name AS label, name + nname AS mixed, code + big AS withmax, nname + nbig AS nwithmax,
       fixed + code AS withchar, 'a' + 'bc' AS literals, '' + code AS emptylit, name + CAST(id AS VARCHAR(10)) AS withcast,
       v5000 + v5000 AS capped, n3000 + n3000 AS ncapped, UPPER(code) + name AS withfunc
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v1') ORDER BY column_id
GO

SELECT label, mixed, withchar, literals, emptylit, withcast, withfunc FROM babel_string_concat_len_v1
GO

-- the value is limited like the described length
SELECT LEN(capped), LEN(ncapped), LEN(withmax), LEN(v5000 + big) FROM babel_string_concat_len_v1, babel_string_concat_len_t1
GO

-- through a subquery, with ORDER BY and in SELECT INTO
SELECT x.label INTO babel_string_concat_len_t2 FROM (SELECT code + '-' + name AS label FROM babel_string_concat_len_t1) x ORDER BY 1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_t2')
GO

-- NULL operands and variables
DECLARE @a VARCHAR(10) = 'abc', @b VARCHAR(20) = NULL, @c NVARCHAR(5) = N'xyz'
SELECT @a + @a AS aa, @a + @b AS anull, @a + @c AS ac, @a + NULL AS litnull
GO

-- numeric addition is not affected
SELECT 1 + 2 AS i, 1.5 + 2 AS n, id + 1 AS c FROM babel_string_concat_len_t1
GO

DROP TABLE babel_string_concat_len_t2
GO

DROP VIEW babel_string_concat_len_v1
GO

DROP TABLE babel_string_concat_len_t1
GO
