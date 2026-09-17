-- ALTER TABLE ... ALTER COLUMN on a column that is used by views
CREATE TABLE babel_alter_column_dep_t1 (id INT NOT NULL, txt VARCHAR(100), d DATETIME, n INT)
GO

INSERT INTO babel_alter_column_dep_t1 VALUES (1, 'abc', '2026-01-01', 10)
GO

-- strong binding (default): the view prevents the type change
CREATE VIEW babel_alter_column_dep_strong AS SELECT id, n FROM babel_alter_column_dep_t1
GO

ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN n BIGINT
GO

SELECT * FROM babel_alter_column_dep_strong
GO

EXEC sp_babelfish_configure 'babelfishpg_tsql.weak_view_binding', 'on'
GO

CREATE VIEW babel_alter_column_dep_v1 AS SELECT id, txt, UPPER(txt) AS utxt, d FROM babel_alter_column_dep_t1
GO

-- view on a view
CREATE VIEW babel_alter_column_dep_v2 AS SELECT txt + 'x' AS tx, d FROM babel_alter_column_dep_v1
GO

-- view that uses the column only in the WHERE clause
CREATE VIEW babel_alter_column_dep_v3 AS SELECT id FROM babel_alter_column_dep_t1 WHERE txt = 'abc'
GO

GRANT SELECT ON babel_alter_column_dep_v1 TO guest
GO

SELECT OBJECT_ID('babel_alter_column_dep_v1') AS v1_id INTO babel_alter_column_dep_ids
GO

-- typmod change
ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN txt VARCHAR(MAX) NULL
GO

-- type change
ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN d VARCHAR(30)
GO

-- the dependent view is queried first
SELECT * FROM babel_alter_column_dep_v2
GO

SELECT * FROM babel_alter_column_dep_v1
GO

SELECT * FROM babel_alter_column_dep_v3
GO

SELECT o.name, c.name, TYPE_NAME(c.user_type_id), c.max_length
FROM sys.columns c JOIN sys.objects o ON c.object_id = o.object_id
WHERE o.name LIKE 'babel_alter_column_dep_v%' ORDER BY o.name, c.column_id
GO

-- the view is still the same object and keeps its permissions
SELECT CASE WHEN OBJECT_ID('babel_alter_column_dep_v1') = v1_id THEN 'same' ELSE 'changed' END FROM babel_alter_column_dep_ids
GO

SELECT HAS_PERMS_BY_NAME('babel_alter_column_dep_v1', 'OBJECT', 'SELECT')
GO

-- with weak view binding the views created with strong binding are handled as well
ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN n BIGINT
GO

SELECT * FROM babel_alter_column_dep_strong
GO

-- a failing ALTER leaves the view untouched
CREATE VIEW babel_alter_column_dep_v4 AS SELECT ABS(n) AS n1 FROM babel_alter_column_dep_t1
GO

ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN n DATE
GO

SELECT * FROM babel_alter_column_dep_v4
GO

-- the type of a computed view column follows the new column type
ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN n VARCHAR(20)
GO

SELECT * FROM babel_alter_column_dep_v4
GO

ALTER TABLE babel_alter_column_dep_t1 ALTER COLUMN n INT
GO

SELECT * FROM babel_alter_column_dep_v4
GO

EXEC sp_babelfish_configure 'babelfishpg_tsql.weak_view_binding', 'off'
GO

DROP VIEW babel_alter_column_dep_v4
GO

DROP VIEW babel_alter_column_dep_v3
GO

DROP VIEW babel_alter_column_dep_v2
GO

DROP VIEW babel_alter_column_dep_v1
GO

DROP VIEW babel_alter_column_dep_strong
GO

DROP TABLE babel_alter_column_dep_ids
GO

DROP TABLE babel_alter_column_dep_t1
GO
