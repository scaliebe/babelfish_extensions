-- after the upgrade sys.databases and DATABASEPROPERTYEX report the options a
-- session effectively runs with, and the compatibility level comes from
-- sys.babelfish_compatibility_level() in sys.databases, sys.sysdatabases and sp_helpdb
SELECT is_ansi_null_default_on, is_ansi_nulls_on, is_ansi_padding_on, is_ansi_warnings_on,
       is_arithabort_on, is_concat_null_yields_null_on, is_quoted_identifier_on, is_numeric_roundabort_on
FROM sys.databases WHERE name = 'babel_db_opt_vals_vu_db';
GO
SELECT CAST(DATABASEPROPERTYEX('babel_db_opt_vals_vu_db', 'IsAnsiNullsEnabled') AS INT) AS ansi_nulls,
       CAST(DATABASEPROPERTYEX('babel_db_opt_vals_vu_db', 'IsQuotedIdentifiersEnabled') AS INT) AS quoted_identifier,
       CAST(DATABASEPROPERTYEX('babel_db_opt_vals_vu_db', 'IsArithmeticAbortEnabled') AS INT) AS arithabort;
GO
SELECT is_local_cursor_default,
       CASE WHEN page_verify_option = CASE WHEN pg_catalog.current_setting('data_checksums') = 'on' THEN 2 ELSE 0 END
             AND page_verify_option_desc = CASE WHEN pg_catalog.current_setting('data_checksums') = 'on' THEN 'CHECKSUM' ELSE 'NONE' END
            THEN 'consistent with data_checksums' ELSE 'inconsistent' END AS page_verify
FROM sys.databases WHERE name = 'babel_db_opt_vals_vu_db';
GO
SELECT sys.babelfish_compatibility_level() AS compatibility_level,
       CAST(SERVERPROPERTY('ProductMajorVersion') AS INT) * 10 AS from_product_version;
GO
SELECT d.compatibility_level, s.cmptlevel, h.compatibility_level AS helpdb_level
FROM sys.databases d
JOIN sys.sysdatabases s ON s.name = d.name
CROSS JOIN sys.babelfish_helpdb('babel_db_opt_vals_vu_db') h
WHERE d.name = 'babel_db_opt_vals_vu_db';
GO
