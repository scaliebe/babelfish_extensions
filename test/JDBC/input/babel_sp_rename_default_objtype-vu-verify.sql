-- sp_rename without @objtype: the type is derived from @objname

-- table, one part name
EXEC sp_rename 'babel_sp_rename_default_objtype_t1', 'babel_sp_rename_default_objtype_t1_new'
GO

-- column, two, three and four part names
EXEC sp_rename 'babel_sp_rename_default_objtype_t1_new.c1', 'c1_new'
GO

EXEC sp_rename 'dbo.babel_sp_rename_default_objtype_t1_new.C2', 'c2_new'
GO

EXEC sp_rename 'master.dbo.babel_sp_rename_default_objtype_t1_new.id', 'id_new'
GO

-- index
EXEC sp_rename 'dbo.babel_sp_rename_default_objtype_t1_new.babel_sp_rename_default_objtype_ix1', 'babel_sp_rename_default_objtype_ix1_new'
GO

-- view, procedure, user defined type
EXEC sp_rename 'dbo.babel_sp_rename_default_objtype_v1', 'babel_sp_rename_default_objtype_v1_new'
GO

EXEC sp_rename N'[dbo].[babel_sp_rename_default_objtype_p1]', N'babel_sp_rename_default_objtype_p1_new', NULL
GO

EXEC sp_rename 'babel_sp_rename_default_objtype_ty1', 'babel_sp_rename_default_objtype_ty1_new'
GO

-- object in another schema
EXEC sp_rename 'babel_sp_rename_default_objtype_s1.babel_sp_rename_default_objtype_t2', 'babel_sp_rename_default_objtype_t2_new'
GO

EXEC sp_rename 'babel_sp_rename_default_objtype_s1.babel_sp_rename_default_objtype_t2_new.c1', 'c1_new'
GO

SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('babel_sp_rename_default_objtype_t1_new') ORDER BY name
GO

SELECT name FROM sys.columns WHERE object_id = OBJECT_ID('babel_sp_rename_default_objtype_s1.babel_sp_rename_default_objtype_t2_new') ORDER BY name
GO

SELECT name FROM sys.indexes WHERE object_id = OBJECT_ID('babel_sp_rename_default_objtype_t1_new') AND name IS NOT NULL ORDER BY name
GO

SELECT name, type FROM sys.objects WHERE name LIKE 'babel_sp_rename_default_objtype_[tvp]%' ORDER BY name
GO

SELECT name FROM sys.types WHERE name LIKE 'babel_sp_rename_default_objtype_ty%' ORDER BY name
GO

-- the name matches a table and a column
EXEC sp_rename 'babel_sp_rename_default_objtype_amb.babel_sp_rename_default_objtype_amb', 'babel_sp_rename_default_objtype_amb_new'
GO

-- an explicit @objtype resolves it
EXEC sp_rename 'babel_sp_rename_default_objtype_amb.babel_sp_rename_default_objtype_amb', 'babel_sp_rename_default_objtype_amb_new', 'COLUMN'
GO

EXEC sp_rename 'babel_sp_rename_default_objtype_amb.babel_sp_rename_default_objtype_amb', 'babel_sp_rename_default_objtype_amb_new'
GO

SELECT s.name, o.name FROM sys.objects o JOIN sys.schemas s ON o.schema_id = s.schema_id WHERE o.name LIKE 'babel_sp_rename_default_objtype_amb%' ORDER BY s.name, o.name
GO

-- no such object or column
EXEC sp_rename 'babel_sp_rename_default_objtype_nothing', 'babel_sp_rename_default_objtype_x'
GO

EXEC sp_rename 'babel_sp_rename_default_objtype_t1_new.nothing', 'babel_sp_rename_default_objtype_x'
GO
