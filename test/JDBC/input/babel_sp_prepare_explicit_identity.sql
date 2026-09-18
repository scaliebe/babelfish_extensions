-- sp_prepare of an INSERT with an explicit value for the identity column.
-- IDENTITY_INSERT is checked when the statement is executed, not when it is
-- prepared.
CREATE TABLE babel_sp_prepare_identity_t1 (id INT IDENTITY(1,1) NOT NULL PRIMARY KEY, note VARCHAR(60) NULL)
GO

-- prepare only
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P1 int, @P2 varchar(60)', N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (@P1, @P2)';
SELECT CASE WHEN @handle IS NOT NULL THEN 'prepared' ELSE 'no handle' END;
EXEC sp_unprepare @handle;
GO

-- prepared and executed while IDENTITY_INSERT is OFF: the execution fails
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P1 int, @P2 varchar(60)', N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (@P1, @P2)';
EXEC sp_execute @handle, 10, 'off';
GO

SELECT COUNT(*) FROM babel_sp_prepare_identity_t1
GO

-- prepared while OFF, executed while ON, and again after it is OFF
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P1 int, @P2 varchar(60)', N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (@P1, @P2)';
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 ON;
EXEC sp_execute @handle, 11, 'on';
EXEC sp_execute @handle, 12, 'on';
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 OFF;
EXEC sp_execute @handle, 13, 'off again';
GO

SELECT id, note FROM babel_sp_prepare_identity_t1 ORDER BY id
GO

-- the identity value follows the explicit values
INSERT INTO babel_sp_prepare_identity_t1 (note) VALUES ('next')
GO

-- prepared while ON, executed after it is OFF
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 ON;
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P1 int, @P2 varchar(60)', N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (@P1, @P2)';
EXEC sp_execute @handle, 21, 'on';
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 OFF;
EXEC sp_execute @handle, 22, 'off';
GO

-- a statement that is not prepared is still rejected right away
INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (30, 'plain')
GO

EXEC sp_executesql N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) VALUES (@P1, @P2)', N'@P1 int, @P2 varchar(60)', 31, 'executesql'
GO

-- INSERT ... SELECT
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P1 int', N'INSERT INTO babel_sp_prepare_identity_t1 (id, note) SELECT @P1, ''select''';
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 ON;
EXEC sp_execute @handle, 41;
SET IDENTITY_INSERT babel_sp_prepare_identity_t1 OFF;
EXEC sp_execute @handle, 40;
GO

-- without a value for the identity column nothing changes
DECLARE @handle INT;
EXEC sp_prepare @handle OUTPUT, N'@P2 varchar(60)', N'INSERT INTO babel_sp_prepare_identity_t1 (note) VALUES (@P2)';
EXEC sp_execute @handle, 'generated';
GO

SELECT id, note FROM babel_sp_prepare_identity_t1 ORDER BY id
GO

DROP TABLE babel_sp_prepare_identity_t1
GO
