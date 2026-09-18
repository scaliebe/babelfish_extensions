-- sys.sp_procedure_params_100_rowset is used by OLE DB providers to derive
-- the parameters of a procedure
EXEC sys.sp_procedure_params_100_rowset N'babel_sp_proc_params_rowset_p1', 1, N'dbo', NULL
GO

-- one parameter, name in another case
EXEC sp_procedure_params_100_rowset 'BABEL_SP_PROC_PARAMS_ROWSET_P1', 1, 'dbo', '@b'
GO

-- the return value only
EXEC sys.sp_procedure_params_100_rowset @procedure_name = 'babel_sp_proc_params_rowset_p1', @procedure_schema = 'dbo', @parameter_name = '@RETURN_VALUE'
GO

-- without schema the procedures of all schemas are returned
EXEC sys.sp_procedure_params_100_rowset 'babel_sp_proc_params_rowset_p1', 1, NULL, '@other'
GO

-- a function
EXEC sys.sp_procedure_params_100_rowset 'babel_sp_proc_params_rowset_f1'
GO

-- another group number and a procedure that does not exist
EXEC sys.sp_procedure_params_100_rowset 'babel_sp_proc_params_rowset_p1', 2, 'dbo', NULL
GO

EXEC sys.sp_procedure_params_100_rowset 'babel_sp_proc_params_rowset_nothing'
GO

-- call with the database name like the provider does
DECLARE @p1 VARCHAR(128) = 'babel_sp_proc_params_rowset_f1', @p2 INT = 1, @p3 VARCHAR(128) = 'dbo', @p4 VARCHAR(128) = NULL
EXEC [master].[sys].sp_procedure_params_100_rowset @p1, @p2, @p3, @p4
GO
