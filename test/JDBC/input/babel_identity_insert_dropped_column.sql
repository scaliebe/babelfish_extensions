-- IDENTITY_INSERT on a table that has a dropped column in front of the
-- identity column. The identity value has to be taken from the identity
-- column and the sequence has to be advanced accordingly.
CREATE TABLE babel_identity_insert_dropped_t1 (junk INT, id INT IDENTITY(1,1) NOT NULL, a VARCHAR(20), b VARCHAR(20))
GO

ALTER TABLE babel_identity_insert_dropped_t1 DROP COLUMN junk
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t1 ON
GO

INSERT INTO babel_identity_insert_dropped_t1 (id, a, b) VALUES (1, 'one', 'x')
GO

INSERT INTO babel_identity_insert_dropped_t1 (id, a, b) VALUES (7, 'seven', 'x'), (5, 'five', 'x')
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t1 OFF
GO

INSERT INTO babel_identity_insert_dropped_t1 (a, b) VALUES ('eight', 'x')
GO

SELECT id, a FROM babel_identity_insert_dropped_t1 ORDER BY id
GO

SELECT CAST(IDENT_CURRENT('babel_identity_insert_dropped_t1') AS INT)
GO

-- dropped column behind the identity column and several dropped columns
CREATE TABLE babel_identity_insert_dropped_t2 (j1 VARCHAR(10), j2 INT, a VARCHAR(20), id BIGINT IDENTITY(10,-1) NOT NULL, j3 INT)
GO

ALTER TABLE babel_identity_insert_dropped_t2 DROP COLUMN j1
GO

ALTER TABLE babel_identity_insert_dropped_t2 DROP COLUMN j2
GO

ALTER TABLE babel_identity_insert_dropped_t2 DROP COLUMN j3
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t2 ON
GO

INSERT INTO babel_identity_insert_dropped_t2 (a, id) VALUES ('three', 3), ('four', 4)
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t2 OFF
GO

INSERT INTO babel_identity_insert_dropped_t2 (a) VALUES ('next')
GO

SELECT id, a FROM babel_identity_insert_dropped_t2 ORDER BY id
GO

-- the TRUNCATE plus IDENTITY_INSERT sequence used by content updates
TRUNCATE TABLE babel_identity_insert_dropped_t1
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t1 ON
GO

INSERT INTO babel_identity_insert_dropped_t1 (id, a, b) VALUES (1, 'one', 'y')
GO

SET IDENTITY_INSERT babel_identity_insert_dropped_t1 OFF
GO

INSERT INTO babel_identity_insert_dropped_t1 (a, b) VALUES ('two', 'y')
GO

SELECT id, a FROM babel_identity_insert_dropped_t1 ORDER BY id
GO

DROP TABLE babel_identity_insert_dropped_t1
GO

DROP TABLE babel_identity_insert_dropped_t2
GO
