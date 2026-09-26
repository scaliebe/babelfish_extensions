-- A T-SQL variable in the source query of PIVOT
CREATE TABLE babel_pivot_lv_t (Jahr INT, Wert INT, Art VARCHAR(10))
GO

INSERT INTO babel_pivot_lv_t VALUES (2024, 5, 'x'), (2025, 10, 'y'), (2026, 20, 'z'), (2026, 7, 'z')
GO

-- in a CASE of the source
DECLARE @Jahr INT = 2026
SELECT * FROM (SELECT us.Jahr, us.Wert, CASE WHEN us.Jahr = @Jahr - 1 THEN 'VorJahr' WHEN us.Jahr = @Jahr THEN 'LfdJahr' ELSE 'Sonst' END AS Zeitraum FROM babel_pivot_lv_t us) src
PIVOT (SUM(Wert) FOR Zeitraum IN ([VorJahr], [LfdJahr])) p ORDER BY Jahr
GO

-- in the WHERE clause of the source, two variables
DECLARE @Von INT = 2025, @Bis INT = 2026
SELECT * FROM (SELECT Wert, Art FROM babel_pivot_lv_t WHERE Jahr BETWEEN @Von AND @Bis) src PIVOT (SUM(Wert) FOR Art IN ([x], [y], [z])) p
GO

-- a variable of a string type and a variable used twice
DECLARE @Art VARCHAR(10) = 'z', @Jahr INT = 2026
SELECT * FROM (SELECT Jahr, Wert, Art FROM babel_pivot_lv_t WHERE Art = @Art AND Jahr = @Jahr) src PIVOT (COUNT(Wert) FOR Art IN ([z])) p WHERE Jahr = @Jahr
GO

-- in a table-valued function and in a procedure
CREATE FUNCTION dbo.babel_pivot_lv_f (@Jahr INT) RETURNS @r TABLE (VorJahr INT, LfdJahr INT) AS
BEGIN
    INSERT INTO @r SELECT VorJahr, LfdJahr FROM (SELECT us.Wert, CASE WHEN us.Jahr = @Jahr - 1 THEN 'VorJahr' WHEN us.Jahr = @Jahr THEN 'LfdJahr' ELSE 'Sonst' END AS Zeitraum FROM babel_pivot_lv_t us) src
                   PIVOT (SUM(Wert) FOR Zeitraum IN ([VorJahr], [LfdJahr])) p
    RETURN
END
GO

SELECT * FROM dbo.babel_pivot_lv_f(2026)
GO

SELECT * FROM dbo.babel_pivot_lv_f(2025)
GO

CREATE PROCEDURE dbo.babel_pivot_lv_p @Jahr INT AS
BEGIN
    DECLARE @Vor INT = @Jahr - 1
    SELECT * FROM (SELECT Jahr, Wert, Art FROM babel_pivot_lv_t WHERE Jahr IN (@Vor, @Jahr)) src PIVOT (SUM(Wert) FOR Art IN ([y], [z])) p ORDER BY Jahr
END
GO

EXEC dbo.babel_pivot_lv_p 2026
GO

-- the plan of the procedure is reused with another value
EXEC dbo.babel_pivot_lv_p 2025
GO

-- a variable that is changed between two executions in one batch
DECLARE @Jahr INT = 2025
SELECT * FROM (SELECT Wert, Art FROM babel_pivot_lv_t WHERE Jahr = @Jahr) src PIVOT (SUM(Wert) FOR Art IN ([y], [z])) p
SET @Jahr = 2026
SELECT * FROM (SELECT Wert, Art FROM babel_pivot_lv_t WHERE Jahr = @Jahr) src PIVOT (SUM(Wert) FOR Art IN ([y], [z])) p
GO

-- without a variable, unchanged
SELECT * FROM (SELECT Wert, Art FROM babel_pivot_lv_t WHERE Jahr = 2026) src PIVOT (SUM(Wert) FOR Art IN ([y], [z])) p
GO

DROP PROCEDURE dbo.babel_pivot_lv_p
GO

DROP FUNCTION dbo.babel_pivot_lv_f
GO

DROP TABLE babel_pivot_lv_t
GO
