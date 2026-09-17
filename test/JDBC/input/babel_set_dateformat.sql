-- SET DATEFORMAT defines how date strings are interpreted
SELECT CAST('12/31/2030' AS DATETIME)
GO

SELECT CAST('31.12.2030' AS DATETIME)
GO

SET DATEFORMAT dmy
GO

SELECT CAST('31.12.2030' AS DATETIME), CAST('01.02.2030' AS SMALLDATETIME), CAST('31/12/2030 10:11' AS DATETIME2(0)), CAST('31-12-2030' AS DATE)
GO

-- formats that do not depend on DATEFORMAT
SELECT CAST('2030-12-31' AS DATE), CAST('20301231' AS DATETIME), CAST('2030-12-31T10:11:12' AS DATETIME)
GO

SELECT CAST('12/31/2030' AS DATETIME)
GO

SELECT ISDATE('31.12.2030'), ISDATE('12/31/2030')
GO

SELECT CONVERT(VARCHAR(10), CAST('05.06.2030' AS DATETIME), 104), MONTH(CAST('05.06.2030' AS DATE)), DATEADD(day, 1, CAST('28.02.2024' AS DATETIME))
GO

-- default values of parameters
CREATE FUNCTION babel_set_dateformat_f1 (@von SMALLDATETIME = '01.01.1900', @bis SMALLDATETIME = '31.12.2030') RETURNS INT AS
BEGIN
    RETURN DATEDIFF(day, @von, @bis)
END
GO

SELECT dbo.babel_set_dateformat_f1(DEFAULT, DEFAULT)
GO

-- string literal and other formats
SET DATEFORMAT 'ymd'
GO

SELECT CAST('30/12/31' AS DATE)
GO

SET DATEFORMAT MDY
GO

SELECT CAST('12/31/2030' AS DATETIME), MONTH(CAST('05.06.2030' AS DATE))
GO

SELECT dbo.babel_set_dateformat_f1(DEFAULT, DEFAULT)
GO

-- inside a procedure the setting is reverted at the end like other SET options
CREATE PROCEDURE babel_set_dateformat_p1 AS
BEGIN
    SET DATEFORMAT dmy
    SELECT MONTH(CAST('05.06.2030' AS DATE))
END
GO

EXEC babel_set_dateformat_p1
GO

SELECT MONTH(CAST('05.06.2030' AS DATE))
GO

-- ydm, myd and dym have no equivalent and stay under the escape hatch
SET DATEFORMAT ydm
GO

SELECT MONTH(CAST('05.06.2030' AS DATE))
GO

EXEC sp_babelfish_configure 'babelfishpg_tsql.escape_hatch_session_settings', 'strict'
GO

SET DATEFORMAT ydm
GO

SET DATEFORMAT dmy
GO

SELECT MONTH(CAST('05.06.2030' AS DATE))
GO

EXEC sp_babelfish_configure 'babelfishpg_tsql.escape_hatch_session_settings', 'ignore'
GO

SET DATEFORMAT mdy
GO

DROP PROCEDURE babel_set_dateformat_p1
GO

DROP FUNCTION babel_set_dateformat_f1
GO
