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

-- the same expression in a condition, in GROUP BY and in ORDER BY
SELECT UPPER(code) AS u FROM babel_string_concat_len_t1 WHERE UPPER(code) = 'DE' AND code + name = 'DEDeutschland' GROUP BY UPPER(code) ORDER BY UPPER(code)
GO

-- aggregates: MIN and MAX keep the length of the argument, STRING_AGG is
-- limited to 8000 (4000) unless the argument is (max)
CREATE VIEW babel_string_concat_len_v3 AS
SELECT MIN(code) AS mn, MAX(name) AS mx, MIN(nname) AS mn_n, MAX(big) AS mx_big, MIN(code + name) AS min_concat, MAX(LEFT(name, 3)) AS max_left,
       RTRIM(MIN(code)) + ' ' + RTRIM(MIN(name)) AS agg_concat,
       CASE WHEN COUNT(DISTINCT id) = 1 THEN RTRIM(MIN(code)) + ' ' + RTRIM(MIN(name)) ELSE CAST(COUNT(DISTINCT id) AS VARCHAR(20)) + ' rows' END AS case_agg,
       COALESCE(MIN(code), '') AS coal_min, ISNULL(MAX(code), '-') AS isn_max, UPPER(MAX(code)) AS up_max,
       STRING_AGG(code, ', ') AS sagg, STRING_AGG(nname, ',') AS sagg_n, STRING_AGG(big, ',') AS sagg_max,
       STRING_AGG(CASE id WHEN 1 THEN 'one' ELSE '<unknown>' END, ', ') AS sagg_case,
       STRING_AGG(code, ',') WITHIN GROUP (ORDER BY code) AS sagg_wg
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v3') ORDER BY column_id
GO

SELECT mn, mx, agg_concat, case_agg, sagg, sagg_case FROM babel_string_concat_len_v3
GO

-- more functions
CREATE VIEW babel_string_concat_len_v4 AS
SELECT STUFF(code, 1, 1, 'xy') AS stf, STUFF(code, 1, 1, NULL) AS stf_null, CONCAT_WS('-', code, name) AS cws, CONCAT_WS('-', code, NULL, name) AS cws_null,
       TRANSLATE(code, 'ab', 'xy') AS trl, FORMAT(id, '000') AS fmt, CONCAT(code, id) AS concat_int, CONCAT(code, NULL, nname) AS concat_mixed,
       DB_NAME() AS dbn, USER_NAME() AS usr
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v4') ORDER BY column_id
GO

SELECT stf, stf_null, cws, cws_null, trl, concat_int, concat_mixed FROM babel_string_concat_len_v4
GO

-- STUFF: not more than what follows the start position is removed, and the
-- result is not cut off
CREATE VIEW babel_string_concat_len_v5 AS
SELECT STUFF(name, 2, 0, code) AS s_ins, STUFF(name, 2, 3, code) AS s_repl, STUFF(name, 2, 100, code) AS s_tail, STUFF(name, 30, 1, code) AS s_last,
       STUFF(name, 31, 1, code) AS s_beyond, STUFF(name, id, 1, code) AS s_var_start, STUFF(name, 2, id, code) AS s_var_len,
       STUFF(name, 2, 3, '') AS s_empty, STUFF(nname, 2, 3, code) AS s_n, CONCAT_WS(NULL, code, name) AS cws_nullsep, CONCAT_WS(code, name, name, name) AS cws_colsep
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v5') ORDER BY column_id
GO

SELECT STUFF(N'abcdef', 2, 7, N'ijklmn') AS s1, STUFF('abcdef', 2, 0, 'ijklmn') AS s2, STUFF('abcdef', 6, 1, 'ijklmn') AS s3, STUFF('abcdef', 1, 6, 'ijklmn') AS s4
GO

-- COLLATE with a collation of a multi-byte code page: the length in bytes is
-- not known, the expression stays (max)
CREATE VIEW babel_string_concat_len_v6 AS
SELECT STUFF(name, 2, 3, code) COLLATE chinese_prc_ci_as AS stf_mb, (code + name) COLLATE chinese_prc_ci_as AS concat_mb,
       (code + name) COLLATE latin1_general_ci_as AS concat_sb, '|' + RTRIM(name) COLLATE chinese_prc_ci_as + '|' AS nested_mb
FROM babel_string_concat_len_t1
GO

SELECT name, TYPE_NAME(user_type_id) AS type_name, max_length
FROM sys.columns WHERE object_id = OBJECT_ID('babel_string_concat_len_v6') ORDER BY column_id
GO

SELECT stf_mb, concat_mb, concat_sb, nested_mb FROM babel_string_concat_len_v6
GO

-- the expression of the target list is found again in ORDER BY, GROUP BY,
-- HAVING and window clauses, also with DISTINCT
SELECT DISTINCT COALESCE(code, '') AS c FROM babel_string_concat_len_t1 WHERE COALESCE(code, '') <> 'x' ORDER BY COALESCE(code, '') ASC
GO

SELECT DISTINCT code + name AS cn FROM babel_string_concat_len_t1 ORDER BY code + name
GO

SELECT DISTINCT UPPER(code) AS u, LEFT(name, 3) AS l FROM babel_string_concat_len_t1 ORDER BY LEFT(name, 3) DESC, UPPER(code)
GO

SELECT code + '-' + name AS cn, COUNT(*) AS cnt FROM babel_string_concat_len_t1 GROUP BY code + '-' + name ORDER BY code + '-' + name
GO

SELECT RTRIM(code) AS c, MAX(name) AS m FROM babel_string_concat_len_t1 GROUP BY RTRIM(code) HAVING RTRIM(code) <> '' ORDER BY MAX(name), RTRIM(code)
GO

SELECT code FROM babel_string_concat_len_t1 ORDER BY UPPER(code) + name
GO

SELECT code + name AS cn, ROW_NUMBER() OVER (PARTITION BY UPPER(code) ORDER BY code + name) AS rn FROM babel_string_concat_len_t1 GROUP BY code + name, UPPER(code) HAVING code + name <> '' ORDER BY code + name
GO

SELECT DISTINCT COALESCE(code, '') + '/' + RTRIM(name) AS c FROM babel_string_concat_len_t1 GROUP BY COALESCE(code, ''), RTRIM(name) HAVING COALESCE(code, '') <> '' ORDER BY COALESCE(code, '') + '/' + RTRIM(name)
GO

SELECT MIN(code) AS m FROM babel_string_concat_len_t1 GROUP BY name ORDER BY MIN(code), STRING_AGG(code, ',')
GO

SELECT code + '-' + name AS cn, UPPER(code + '-' + name) AS ucn, RANK() OVER (ORDER BY code + '-' + name) AS rk FROM babel_string_concat_len_t1 WHERE code + '-' + name <> '' GROUP BY code + '-' + name HAVING code + '-' + name <> '' AND MAX(RTRIM(name) + code) <> ''
GO

SELECT x.cn FROM (SELECT code + '-' + name AS cn FROM babel_string_concat_len_t1 GROUP BY code + '-' + name) x JOIN babel_string_concat_len_t1 t ON x.cn = t.code + '-' + t.name
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

DROP VIEW babel_string_concat_len_v6
GO

DROP VIEW babel_string_concat_len_v5
GO

DROP VIEW babel_string_concat_len_v4
GO

DROP VIEW babel_string_concat_len_v3
GO

DROP VIEW babel_string_concat_len_v2
GO

DROP VIEW babel_string_concat_len_v1
GO

DROP TABLE babel_string_concat_len_t1
GO
