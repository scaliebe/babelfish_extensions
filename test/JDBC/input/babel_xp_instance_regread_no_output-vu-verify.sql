-- xp_instance_regread with the optional fifth argument 'no_output'
DECLARE @dir NVARCHAR(512)
EXEC master.dbo.xp_instance_regread
      N'HKEY_LOCAL_MACHINE'
    , N'Software\Microsoft\MSSQLServer\Setup'
    , N'SQLPath'
    , @dir OUTPUT
    , 'no_output'
SELECT @dir
GO

DECLARE @val INT
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'NumErrorLogs', @val OUTPUT, 'no_output'
SELECT @val
GO

DECLARE @dir NVARCHAR(512)
EXEC sys.xp_instance_regread N'RootKey', N'Key', N'Value', @dir OUTPUT, N'no_output'
SELECT @dir
GO

DECLARE @val INT
EXEC xp_instance_regread N'RootKey', N'Key', N'Value', @val OUTPUT, 'no_output'
SELECT @val
GO

-- the variants with four arguments still work
DECLARE @dir NVARCHAR(512)
EXEC master.dbo.xp_instance_regread N'RootKey', N'Key', N'Value', @dir OUTPUT
SELECT @dir
GO

EXEC babel_xp_instance_regread_no_output_p1
GO

-- too many arguments
DECLARE @dir NVARCHAR(512)
EXEC master.dbo.xp_instance_regread N'RootKey', N'Key', N'Value', @dir OUTPUT, 'no_output', 'x'
GO
