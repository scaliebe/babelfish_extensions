CREATE PROCEDURE babel_xp_instance_regread_no_output_p1 AS
BEGIN
    DECLARE @dir NVARCHAR(512)
    EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\Setup', N'SQLPath', @dir OUTPUT, 'no_output'
    SELECT @dir
END
GO
