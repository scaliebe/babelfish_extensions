-- A keyword or an identifier can follow a numeric literal without white space
CREATE TABLE babel_number_followed_t (Mitarbeiter INT, AbrechMonat INT, AbrechJahr INT)
GO

INSERT INTO babel_number_followed_t VALUES (96, 5, 2026), (96, 0, 2026), (7, 3, 2025)
GO

SELECT MIN(AbrechJahr*100+AbrechMonat) AS Min, MAX(AbrechJahr*100+AbrechMonat) AS Max FROM babel_number_followed_t WHERE Mitarbeiter = 96AND AbrechMonat > 0
GO

SELECT COUNT(*) FROM babel_number_followed_t WHERE Mitarbeiter = 96OR AbrechMonat = 3
GO

SELECT COUNT(*) FROM babel_number_followed_t WHERE AbrechMonat IN (3,5)AND Mitarbeiter = 96ORDER BY 1
GO

SELECT Mitarbeiter FROM babel_number_followed_t WHERE AbrechMonat BETWEEN 1AND 4
GO

SELECT TOP 1Mitarbeiter FROM babel_number_followed_t ORDER BY 1DESC
GO

SELECT 96FROM babel_number_followed_t WHERE AbrechMonat = 5
GO

SELECT 1union SELECT 2
GO

-- decimal and float literals
SELECT COUNT(*) FROM babel_number_followed_t WHERE AbrechMonat > 2.5AND AbrechMonat < 1e1AND Mitarbeiter <> .5OR 1 = 0
GO

SELECT 1a, 1.5b, 2.c, .5d, 1e5e, 1.5e3f
GO

-- E without an exponent belongs to the number, like in SQL Server
SELECT CASE WHEN 1 = 1 THEN 96END
GO

SELECT CASE WHEN 1 = 1 THEN 96 ELSE 5END
GO

SELECT CASE WHEN 1 = 1 THEN 96 ELSE 5 END
GO

-- in a procedure, a function, a view and dynamic SQL
CREATE PROCEDURE babel_number_followed_p @m INT AS
BEGIN
    DECLARE @n INT = 0
    IF @m = 96SET @n = 1
    SELECT @n, COUNT(*) FROM babel_number_followed_t WHERE Mitarbeiter = @m AND AbrechMonat > 0AND AbrechJahr = 2026
END
GO

EXEC babel_number_followed_p 96
GO

EXEC babel_number_followed_p 7
GO

CREATE FUNCTION babel_number_followed_f (@m INT) RETURNS INT AS
BEGIN
    RETURN (SELECT COUNT(*) FROM babel_number_followed_t WHERE Mitarbeiter = @m AND AbrechMonat >= 0AND AbrechJahr > 2000)
END
GO

SELECT dbo.babel_number_followed_f(96)
GO

CREATE VIEW babel_number_followed_v AS SELECT Mitarbeiter FROM babel_number_followed_t WHERE AbrechMonat > 0AND AbrechJahr = 2026
GO

SELECT * FROM babel_number_followed_v
GO

EXEC sp_executesql N'SELECT COUNT(*) FROM babel_number_followed_t WHERE Mitarbeiter = @P1 AND AbrechMonat > 0AND AbrechJahr = 2026', N'@P1 INT', 96
GO

EXEC('SELECT COUNT(*) FROM babel_number_followed_t WHERE Mitarbeiter = 96AND AbrechMonat > 0')
GO

DROP VIEW babel_number_followed_v
GO

DROP FUNCTION babel_number_followed_f
GO

DROP PROCEDURE babel_number_followed_p
GO

DROP TABLE babel_number_followed_t
GO
