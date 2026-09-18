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

-- COALESCE and the string functions report the same length as SQL Server
CREATE VIEW babel_string_concat_len_v2 AS
SELECT COALESCE(code, '') AS coal, COALESCE(code, '') + ' ' + COALESCE(name, '') AS coal_concat,
       COALESCE(code, name, 'x') AS coal3, COALESCE(nname, code) AS coal_mixed, COALESCE(code, big) AS coal_max,
       ISNULL(code, '') + '-' + ISNULL(name, 'x') AS isn_concat,
       CASE WHEN id = 1 THEN code ELSE 'n/a' END + '!' AS case_concat,
       UPPER(code) AS up, LOWER(code) + 'x' AS low_concat, LTRIM(RTRIM(name)) AS trimmed, RTRIM(fixed) + code AS rtrim_char,
       LEFT(name, 5) AS lft, RIGHT(name, 5) + 'x' AS rgt_concat, LEFT(code, 10) AS lft_short, SUBSTRING(name, 1, 3) AS sub, SUBSTRING(name, id, id) AS sub_var,
       REPLACE(code, 'a', 'bb') AS rep, REPLICATE(code, 2) AS repl, REPLICATE(code, id) AS repl_var, SPACE(3) + code AS spc,
       STR(id) + code AS str_concat, STR(id, 5) + code AS str5_concat, CONCAT(code, ' ', name) AS concat_fn, CONCAT(code, id) AS concat_int,
       QUOTENAME(code) AS qn, REVERSE(code) + 'x' AS rev, UPPER(big) AS up_max, CAST(code AS VARCHAR(MAX)) + 'x' AS cast_max
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v2') ORDER BY column_id
GO

SELECT coal_concat, coal3, coal_mixed, up, trimmed, lft, sub, repl, spc, str_concat, concat_fn, qn, rev FROM babel_string_concat_len_v2
GO

-- only the target list gets the length; the same expression in a condition,
-- in GROUP BY and in ORDER BY still matches
SELECT UPPER(code) AS u FROM babel_string_concat_len_t1 WHERE UPPER(code) = 'DE' AND code + name = 'DEDeutschland' GROUP BY UPPER(code) ORDER BY UPPER(code)
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

DROP VIEW babel_string_concat_len_v2
GO

DROP VIEW babel_string_concat_len_v1
GO

DROP TABLE babel_string_concat_len_t1
GO
