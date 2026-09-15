-- after the upgrade @@LANGID resolves and matches sys.syslanguages
SELECT CASE WHEN @@LANGID = (SELECT langid FROM sys.syslanguages WHERE name = @@LANGUAGE) THEN 'consistent' ELSE 'inconsistent' END AS langid_check;
GO
SELECT lcid, alias FROM sys.syslanguages WHERE langid = @@Langid;
GO
SELECT id, @@LANGID AS langid FROM babel_langid_vu_prepare_t;
GO
SELECT langid, alias, lcid FROM sys.syslanguages WHERE name IN ('us_english', 'Deutsch', 'British') ORDER BY langid;
GO
