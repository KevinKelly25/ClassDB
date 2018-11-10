--addFrequentViewsReco.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy, Kevin Kelly
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This file has been modified from the original by WADE (Web Applications
-- and Databases for Education). All original authors are kept as-is on line
-- 3 and WADE authors added to the end, if any member made significant changes.
-- These modifications were made to support a web application that relies 
-- heavily on ClassDB.

--This script should be run as either a superuser or a user with write access
-- to the ClassDB and PUBLIC schemas

--This script should be run in every database to which ClassDB is to be added
-- it should be run after running addUserMgmtCore.sql

--This script creates several objects (we collectively refer to them as views) to
-- display summary data related to student activity in the current database.
-- Views that are accessible to students and require access to ClassDB.User are
-- implemented as functions. This allows the views to access the ClassDB schema
-- though students cannot directly access the schema.


START TRANSACTION;

--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT ClassDB.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user with'
                      ' superuser privileges';
   END IF;
END
$$;

--Suppress NOTICE messages for this script only, this will not apply to functions
-- defined within. This hides messages that are unimportant, but possibly confusing
SET LOCAL client_min_messages TO WARNING;



--UPGRADE FROM 2.0 TO 2.1
-- These statements are needed when upgrading ClassDB from 2.0 to 2.1
-- These can be removed in a future version of ClassDB

--Remove functions which have had their return types changed and their dependents
-- We avoid using DROP...CASACDE in case users have created custom objects based on
-- ClassDB objects
DROP VIEW IF EXISTS public.MyActivity;
DROP FUNCTION IF EXISTS public.getMyActivity();

DROP VIEW IF EXISTS ClassDB.StudentActivityAnon;
DROP FUNCTION IF EXISTS ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS ClassDB.StudentActivity;
DROP FUNCTION IF EXISTS ClassDB.getStudentActivity(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS ClassDB.getUserActivity(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS public.MyConnectionActivity;
DROP FUNCTION IF EXISTS public.getMyConnectionActivity();
DROP FUNCTION IF EXISTS ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain);

DROP VIEW IF EXISTS public.MyDDLActivity;
DROP FUNCTION IF EXISTS public.getMyDDLActivity();
DROP FUNCTION IF EXISTS ClassDB.getUserDDLActivity(ClassDB.IDNameDomain);


--This view returns all tables and views owned by users
-- uses pg_catalog instead of INFORMATION_SCHEMA because the latter does not
-- support the case where a table owner and the containing schema's owner are
-- different.
CREATE OR REPLACE VIEW ClassDB.UserTables AS
(
  SELECT tableowner Username, schemaname SchemaName, tablename TableName, 
         'TABLE' TableType, hasindexes HasIndexes, hastriggers HasTriggers,
         hasrules HasRules
  FROM pg_catalog.pg_tables
  WHERE SchemaName NOT IN ('pg_catalog','classdb','information_schema')

  UNION

  SELECT ViewOwner, SchemaName, ViewName, 'VIEW', NULL, NULL, NULL
  FROM pg_catalog.pg_views
  WHERE SchemaName NOT IN ('pg_catalog','classdb','information_schema')
  ORDER BY UserName, SchemaName, TableName
);

ALTER VIEW ClassDB.UserTables OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.UserTables FROM PUBLIC;
GRANT SELECT ON ClassDB.UserTables TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all tables and views owned by student users
-- does not use view ClassDB.Student for efficiency: that view computes many
-- things not required here, and using that would require a join
-- this view is accessible only to instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTable AS
(
  SELECT Username, SchemaName, TableName,TableType, HasIndexes, 
         HasTriggers, HasRules
  FROM ClassDB.UserTables
  WHERE ClassDB.isStudent(UserName::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.StudentTable OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentTable FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentTable TO ClassDB_Admin, ClassDB_Instructor;



--This view returns the number of tables and views each student user owns
-- this view is accessible only to instructors.
CREATE OR REPLACE VIEW ClassDB.StudentTableCount AS
(
  SELECT UserName, COUNT(*) TableCount
  FROM ClassDB.StudentTable
  GROUP BY UserName
  ORDER BY UserName
);

ALTER VIEW ClassDB.StudentTableCount OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentTableCount FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentTableCount TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all functions and procedures owned by users
-- pg_proc contains all function information. pg_namespace is joined to get
-- schema name and owner's OID which in then used to get role name from the
-- table pg_roles
CREATE OR REPLACE VIEW ClassDB.UserFunctions AS
(
  SELECT r.rolname AS Username , n.nspname AS SchemaName, 
         p.proname AS FunctionName, p.pronargs AS NumberOfArguments, 
         p.prorettype AS ReturnType
  FROM pg_catalog.pg_proc p 
  INNER JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
  INNER JOIN pg_catalog.pg_roles r ON p.proowner = r.oid
  WHERE n.nspname NOT IN ('pg_catalog','classdb','information_schema')
);

ALTER VIEW ClassDB.UserFunctions OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.UserFunctions FROM PUBLIC;
GRANT SELECT ON ClassDB.UserFunctions TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all Functions and procedures owned by students
CREATE OR REPLACE VIEW ClassDB.StudentFunctions AS
(
  SELECT Username, SchemaName, FunctionName, NumberOfArguments, ReturnType
  FROM ClassDB.UserFunctions
  WHERE ClassDB.isStudent(UserName::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.StudentFunctions OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentFunctions FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentFunctions TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all triggers owned by users
-- pg_class contains the trigger name and the associated table's name, both are
-- matched by OID stored in pg_trigger. pg_namespace is used to get get schema.
-- pg_roles is used to get the owner of the object
CREATE OR REPLACE VIEW ClassDB.UserTriggers AS
(
  SELECT r.rolname AS Username, n.nspname AS SchemaName,
         t.tgname AS TriggerName, c.relname AS OnTable
  FROM pg_catalog.pg_trigger t
  INNER JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
  INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  INNER JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
  WHERE n.nspname NOT IN ('pg_catalog','classdb','information_schema')
);

ALTER VIEW ClassDB.UserTriggers OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.UserTriggers FROM PUBLIC;
GRANT SELECT ON ClassDB.UserTriggers TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all triggers owned by students
CREATE OR REPLACE VIEW ClassDB.StudentTriggers AS
(
  SELECT Username, SchemaName, TriggerName, OnTable
  FROM ClassDB.UserTriggers
  WHERE ClassDB.isStudent(UserName::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.StudentTriggers OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentTriggers FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentTriggers TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all indexes owned by users
-- pg_class contains the index name and the associated table's name, both are
-- matched by OID stored in pg_index. pg_namespace is used to get get schema.
-- pg_roles is used to get the owner of the object
CREATE OR REPLACE VIEW ClassDB.UserIndexes AS
(
  SELECT r.rolname AS Username, n.nspname AS SchemaName, 
         c2.relname AS IndexName, c.relname AS OnTable
  FROM pg_catalog.pg_index i
  INNER JOIN pg_catalog.pg_class c ON c.oid = i.indexrelid
  INNER JOIN pg_catalog.pg_class c2 ON c2.oid = i.indrelid
  INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  INNER JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
  WHERE c.reltype = 0 AND 
    n.nspname NOT IN ('pg_catalog','classdb','information_schema','pg_toast')
);

ALTER VIEW ClassDB.UserIndexes OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.UserIndexes FROM PUBLIC;
GRANT SELECT ON ClassDB.UserIndexes TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all indexes owned by students
CREATE OR REPLACE VIEW ClassDB.StudentIndexes AS
(
  SELECT Username, SchemaName, IndexName, OnTable
  FROM ClassDB.UserIndexes
  WHERE ClassDB.isStudent(UserName::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.StudentIndexes OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentIndexes FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentIndexes TO ClassDB_Admin, ClassDB_Instructor;


--This view returns all major objects owned by users
CREATE OR REPLACE VIEW ClassDB.MajorUserObjects AS
(
  SELECT Username, SchemaName, TableName AS Name, TableType AS Type
  FROM ClassDB.UserTables

  UNION

  SELECT Username, SchemaName, FunctionName, 'FUNCTION'
  FROM ClassDB.UserFunctions

  UNION 

  SELECT Username, SchemaName, TriggerName, 'TRIGGER'
  FROM ClassDB.UserTriggers

  UNION 

  SELECT Username, SchemaName, IndexName, 'INDEX'
  FROM ClassDB.UserIndexes
  ORDER BY UserName, SchemaName, Type
);

ALTER VIEW ClassDB.MajorUserObjects OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.MajorUserObjects FROM PUBLIC;
GRANT SELECT ON ClassDB.MajorUserObjects TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all major objects owned by students
CREATE OR REPLACE VIEW ClassDB.MajorStudentObjects AS
(
  SELECT Username, SchemaName, Name, Type
  FROM ClassDB.MajorUserObjects
  WHERE ClassDB.isStudent(UserName::ClassDB.IDNameDomain)
);

ALTER VIEW ClassDB.MajorStudentObjects OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.MajorStudentObjects FROM PUBLIC;
GRANT SELECT ON ClassDB.MajorStudentObjects TO ClassDB_Admin, ClassDB_Instructor;



--This function gets and returns the details of a table when given a table name
-- and username. Returns all the table description info from pg_tables and 
-- also the column types
CREATE OR REPLACE FUNCTION 
  ClassDB.getTableDetails(InputSchemaname ClassDB.IDNameDomain,
                          InputTableName VARCHAR(63))
RETURNS TABLE
(
   Username NAME, SchemaName NAME, 
   TableName NAME, HasIndexes BOOLEAN, 
   HasTriggers BOOLEAN, HasRules BOOLEAN, Attributes TEXT
) AS
$$
DECLARE
  Table_OID OID; --The OID of the table
  Attributes TEXT;--Variable to store all the variable types to be returned
  r RECORD;--Used in for loop to hold "counter"
BEGIN
   --Find OID of the designated table to be used later in function
   SELECT c.oid INTO Table_OID
   FROM pg_catalog.pg_class c INNER JOIN pg_catalog.pg_namespace n 
   ON n.oid = c.relnamespace
   WHERE n.nspname = $1 AND c.relname = $2;
   
   --Loop through each column to find each associated type and concatenate to a 
   -- single variable to be returned
   FOR r IN
      SELECT a.atttypid
      FROM pg_catalog.pg_attribute a
      WHERE a.attrelid = Table_OID AND a.attnum > 0
   LOOP
      IF Attributes IS NULL THEN 
         Attributes = (SELECT typname
                        FROM pg_type
                        WHERE OID = r.atttypid);
      ELSE 
         Attributes = CONCAT(Attributes, ', ', (SELECT typname
                                                 FROM pg_type
                                                 WHERE OID = r.atttypid));
      END IF;
   END LOOP;

   --Return all details of pg_table and the added column attribute types
   RETURN QUERY SELECT t.tableowner AS Username, t.schemaname AS SchemaName,
          t.tablename AS TableName, t.hasindexes AS HasIndexes, 
          t.hastriggers AS HasTriggers, t.hasrules AS HasRules,
          Attributes AS AttributeTypes
   FROM pg_catalog.pg_tables t
   WHERE t.Schemaname = $1 AND t.Tablename = $2;
END;
$$ LANGUAGE plpgsql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getTableDetails(ClassDB.IDNameDomain, VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getTableDetails(ClassDB.IDNameDomain, 
                                               VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getTableDetails(ClassDB.IDNameDomain,
                                                  VARCHAR(63))
   TO ClassDB_Admin, ClassDB_Instructor;


--This function gets and returns the details of a view when given a view
-- name and username. 
CREATE OR REPLACE FUNCTION 
  ClassDB.getViewDetails(InputSchemaname ClassDB.IDNameDomain,
                         InputViewName VARCHAR(63))
RETURNS TABLE
(
   Username NAME, SchemaName NAME, ViewName NAME, Definition TEXT
) AS
$$
  SELECT viewowner, schemaname, viewname, definition
  FROM pg_catalog.pg_views v
  WHERE schemaname = $1 AND viewname = $2;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getViewDetails(ClassDB.IDNameDomain, VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getViewDetails(ClassDB.IDNameDomain, VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getViewDetails(ClassDB.IDNameDomain,
                                                 VARCHAR(63))
   TO ClassDB_Admin, ClassDB_Instructor;


--This function gets and returns the details of a Function when given a function
-- name and username. 
CREATE OR REPLACE FUNCTION 
  ClassDB.getFunctionDetails(InputSchemaname ClassDB.IDNameDomain,
                             InputFunctionName VARCHAR(63))
RETURNS TABLE
(
   Username NAME, SchemaName NAME, FunctionName NAME, NumberOfArguments INT2, 
   ReturnType NAME, EstimatedReturnRows FLOAT4, isAggregate BOOLEAN, 
   isWindowFunction BOOLEAN, isSecurityDefiner BOOLEAN, 
   returnsResultSet BOOLEAN, ArgumentTypes TEXT, SourceCode TEXT
) AS
$$
  SELECT r.rolname, n.nspname,p.proname, p.pronargs, t.typname, p.prorows,
         p.proisagg, p.proiswindow, p.prosecdef, p.proretset,
         pg_catalog.pg_get_function_arguments(p.oid),p.prosrc
  FROM pg_catalog.pg_proc p 
  INNER JOIN pg_catalog.pg_namespace n ON p.pronamespace = n.oid 
  INNER JOIN pg_catalog.pg_roles r ON p.proowner = r.oid
  INNER JOIN pg_catalog.pg_type t ON p.prorettype = t.oid
  WHERE n.nspname = LOWER($1) AND p.proname = LOWER($2);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getFunctionDetails(ClassDB.IDNameDomain, VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getFunctionDetails(ClassDB.IDNameDomain,
                                                  VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getFunctionDetails(ClassDB.IDNameDomain,
                                                     VARCHAR(63))
   TO ClassDB_Admin, ClassDB_Instructor;


--This function gets and returns the details of a trigger when given a trigger
-- name and username. 
CREATE OR REPLACE FUNCTION 
  ClassDB.getTriggerDetails(InputSchemaname ClassDB.IDNameDomain,
                            InputTriggerName VARCHAR(63))
RETURNS TABLE
(
   Username NAME, SchemaName NAME, TriggerName NAME, OnTable NAME, 
   OnFunction NAME 
) AS
$$
  SELECT r.rolname, n.nspname, t.tgname, c.relname, p.proname
  FROM pg_catalog.pg_trigger t
  INNER JOIN pg_catalog.pg_class c ON c.oid = t.tgrelid
  INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  INNER JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
  INNER JOIN pg_catalog.pg_proc p ON p.oid = t.tgfoid
  WHERE n.nspname = $1 AND t.tgname = $2
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getTriggerDetails(ClassDB.IDNameDomain, VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getTriggerDetails(ClassDB.IDNameDomain,
                                                  VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getTriggerDetails(ClassDB.IDNameDomain,
                                                     VARCHAR(63))
   TO ClassDB_Admin, ClassDB_Instructor;



--This function gets and returns the details of a Function when given a function
-- name and username. 
CREATE OR REPLACE FUNCTION 
  ClassDB.getIndexDetails(InputSchemaname ClassDB.IDNameDomain,
                          InputIndexName VARCHAR(63))
RETURNS TABLE
(
   Username NAME, SchemaName NAME, IndexName NAME, OnTable NAME, 
   NumberOfColums SMALLINT, isUnique BOOLEAN, isPrimaryKey BOOLEAN, 
   IndexDefinition TEXT
) AS
$$
  SELECT r.rolname, n.nspname, c.relname, c2.relname, i.indnatts, i.indisunique,
         i.indisprimary, i2.indexdef
  FROM pg_catalog.pg_index i
  INNER JOIN pg_catalog.pg_class c ON c.oid = i.indexrelid
  INNER JOIN pg_catalog.pg_class c2 ON c2.oid = i.indrelid
  INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
  INNER JOIN pg_catalog.pg_roles r ON r.oid = c.relowner
  INNER JOIN pg_catalog.pg_indexes i2 ON i2.indexname = c.relname
  WHERE n.nspname = $1 and c.relname = $2;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getIndexDetails(ClassDB.IDNameDomain, VARCHAR(63))
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getIndexDetails(ClassDB.IDNameDomain,
                                               VARCHAR(63))
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getIndexDetails(ClassDB.IDNameDomain,
                                                  VARCHAR(63))
   TO ClassDB_Admin, ClassDB_Instructor;



--This function gets the user activity summary for a given user. A value of NULL
-- will return activity summaries for all ClassDB users. This includes their
-- latest DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getUserActivitySummary(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   --We COALESCE the input user name with '%' so that the function will either
   -- match a single user name, or all user names
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject,
          ClassDB.changeTimeZone(LastDDLActivityAtUTC) LastDDLActivityAt,
          ConnectionCount, ClassDB.changeTimeZone(LastConnectionAtUTC) LastConnectionAt
   FROM ClassDB.User
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivitySummary(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--This function gets the user activity summary for a given student. A value of
-- NULL will return activity summaries for all students. This includes their
-- latest DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummary(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, DDLCount BIGINT, LastDDLOperation VARCHAR,
   LastDDLObject VARCHAR, LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT,
   LastConnectionAt TIMESTAMP
) AS
$$
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary($1)
   WHERE ClassDB.isStudent(UserName);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummary(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--A view that wraps getStudentActivitySummary() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivitySummary AS
(
   SELECT UserName, DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM   ClassDB.getStudentActivitySummary()
);

ALTER VIEW ClassDB.StudentActivitySummary OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivitySummary FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivitySummary 
      TO ClassDB_Admin, ClassDB_Instructor;



--Return activity summaries for all students. This includes their latest
-- DDL and connection activity, as well as their total number of DDL and
-- Connection events
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivitySummaryAnon(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR, LastDDLObject VARCHAR,
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT DDLCount, LastDDLOperation,
          SUBSTRING(LastDDLObject, POSITION('.' IN lastddlobject)+1)  LastDDLObject,
          LastDDLActivityAt, ConnectionCount, LastConnectionAt
   FROM ClassDB.getStudentActivitySummary($1)
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivitySummaryAnon(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--A view that wraps getStudentActivitySummaryAnon() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivitySummaryAnon AS
(
   SELECT DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM   ClassDB.getStudentActivitySummaryAnon()
);

ALTER VIEW ClassDB.StudentActivitySummaryAnon OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivitySummaryAnon FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivitySummaryAnon 
      TO ClassDB_Admin, ClassDB_Instructor;



--This function lists the most recent activity of the executing user. This view
-- is accessible by both students and instructors, which requires that it be
-- placed in the public schema. Additionally, it is implemented as a function
-- so that students are able to indirectly access ClassDB.User.
CREATE OR REPLACE FUNCTION public.getMyActivitySummary()
RETURNS TABLE
(
   DDLCount BIGINT, LastDDLOperation VARCHAR, LastDDLObject VARCHAR,
   LastDDLActivityAt TIMESTAMP, ConnectionCount BIGINT, LastConnectionAt TIMESTAMP
) AS
$$
   SELECT DDLCount, LastDDLOperation, LastDDLOperation,  LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM ClassDB.getUserActivitySummary(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyActivitySummary() OWNER TO ClassDB;



--Proxy view for public.getMyActivitySummary(). Designed to make access easier
-- for students
CREATE OR REPLACE VIEW public.MyActivitySummary AS
(
   SELECT DDLCount, LastDDLObject, LastDDLActivityAt,
          ConnectionCount, LastConnectionAt
   FROM public.getMyActivitySummary()
);

ALTER VIEW public.MyActivitySummary OWNER TO ClassDB;
GRANT SELECT ON public.MyActivitySummary TO PUBLIC;



--This function returns all DDL activity for a specified user. Passing NULL
-- returns data for all users
CREATE OR REPLACE FUNCTION ClassDB.getUserDDLActivity(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, StatementStartedAt TIMESTAMP, SessionID VARCHAR(17),
   DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT UserName, ClassDB.changeTimeZone(StatementStartedAtUTC) StatementStartedAt,
          SessionID, DDLOperation, DDLObject
   FROM ClassDB.DDLActivity
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName, StatementStartedAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserDDLActivity(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--This function returns all DDL activity for the current user
CREATE OR REPLACE FUNCTION public.getMyDDLActivity()
RETURNS TABLE
(
   StatementStartedAt TIMESTAMP, SessionID VARCHAR(17), DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   SELECT StatementStartedAt, SessionID, DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyDDLActivity() OWNER TO ClassDB;



--This view wraps getMyDDLActivity() for easier student access
CREATE OR REPLACE VIEW public.MyDDLActivity AS
(
   SELECT StatementStartedAt, SessionID, DDLOperation, DDLObject
   FROM public.getMyDDLActivity()
);

ALTER VIEW public.MyDDLActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyDDLActivity TO PUBLIC;



--This function returns all connection activity for a specified user. This includes
-- all connections and disconnections. Passing NULL returns data for all users
CREATE OR REPLACE FUNCTION ClassDB.getUserConnectionActivity(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain
) AS
$$
   SELECT UserName, ClassDB.changeTimeZone(ActivityAtUTC) ActivityAt,
          CASE WHEN ActivityType = 'C' THEN 'Connection'
          ELSE 'Disconnection' END ActivityType,
          SessionID, ApplicationName
   FROM ClassDB.ConnectionActivity
   WHERE UserName LIKE COALESCE(ClassDB.foldPgID($1), '%')
   ORDER BY UserName, ActivityAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserConnectionActivity(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--This function returns all connection activity for the current user
CREATE OR REPLACE FUNCTION public.getMyConnectionActivity()
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName
   FROM ClassDB.getUserConnectionActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyConnectionActivity() OWNER TO ClassDB;



--This view wraps getMyConnectionActivity for easier student access
CREATE OR REPLACE VIEW public.MyConnectionActivity AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName
   FROM public.getMyConnectionActivity()
);

ALTER VIEW public.MyConnectionActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyConnectionActivity TO PUBLIC;



--This function returns all activity for a specified user. Passing NULL provides
-- data for all users. This function returns both connection and DDL activity.
-- The ActivityType column specifies this, either 'Connection', 'Disconnection',
-- or 'DDL Query'. For connection activity rows, the DDLOperation and DDLObject columns
-- are not applicable, will be NULL. Likewise, SessionID and ApplicationID are
-- not applicable to DDL activity.
CREATE OR REPLACE FUNCTION ClassDB.getUserActivity(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   --Postgres requires casting NULL to IDNameDomain, it will not do this coercion
   SELECT UserName, StatementStartedAt AS ActivityAt, 'DDL Query', SessionID,
          NULL::ClassDB.IDNameDomain, DDLOperation, DDLObject
   FROM ClassDB.getUserDDLActivity(COALESCE($1, '%'))
   UNION ALL
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, NULL, NULL
   FROM ClassDB.getUserConnectionActivity(COALESCE($1, '%'))
   ORDER BY UserName, ActivityAt DESC;
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getUserActivity(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--This function returns all activity for a specified student. Passing NULL provides
-- data for all students
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivity(userName ClassDB.IDNameDomain
   DEFAULT NULL)
RETURNS TABLE
(
   UserName ClassDB.IDNameDomain, ActivityAt TIMESTAMP, ActivityType VARCHAR,
   SessionID VARCHAR(17), ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR,
   DDLObject VARCHAR
) AS
$$
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity(COALESCE($1, '%'))
   WHERE ClassDB.isStudent(UserName);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain) OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivity(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--A view that wraps getStudentActivity() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivity AS
(
   SELECT UserName, ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM   ClassDB.getStudentActivity()
);

ALTER VIEW ClassDB.StudentActivity OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivity FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivity TO ClassDB_Admin, ClassDB_Instructor;



--This function returns all activity for a specified student. Returns
-- anonymized data. Passing NULL provides data for all students
CREATE OR REPLACE FUNCTION ClassDB.getStudentActivityAnon(
   userName ClassDB.IDNameDomain DEFAULT NULL)
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation,
          SUBSTRING(DDLObject, POSITION('.' IN DDLObject)+1) DDLObject
   FROM ClassDB.getStudentActivity(COALESCE($1, '%'));
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   OWNER TO ClassDB;
REVOKE ALL ON FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   FROM PUBLIC;
GRANT EXECUTE ON FUNCTION ClassDB.getStudentActivityAnon(ClassDB.IDNameDomain)
   TO ClassDB_Admin, ClassDB_Instructor;



--A view that wraps getStudentActivityAnon() for easier access
CREATE OR REPLACE VIEW ClassDB.StudentActivityAnon AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM   ClassDB.getStudentActivityAnon()
);

ALTER VIEW ClassDB.StudentActivityAnon OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.StudentActivityAnon FROM PUBLIC;
GRANT SELECT ON ClassDB.StudentActivityAnon TO ClassDB_Admin, ClassDB_Instructor;



--This view returns all activity for the current user
CREATE OR REPLACE FUNCTION public.getMyActivity()
RETURNS TABLE
(
   ActivityAt TIMESTAMP, ActivityType VARCHAR, SessionID VARCHAR(17),
   ApplicationName ClassDB.IDNameDomain, DDLOperation VARCHAR, DDLObject VARCHAR
) AS
$$
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM ClassDB.getUserActivity(SESSION_USER::ClassDB.IDNameDomain);
$$ LANGUAGE sql
   STABLE
   SECURITY DEFINER;

ALTER FUNCTION public.getMyActivity() OWNER TO ClassDB;



--This view wraps getMyActivity() for easier student access
CREATE OR REPLACE VIEW public.MyActivity AS
(
   SELECT ActivityAt, ActivityType, SessionID, ApplicationName, DDLOperation, DDLObject
   FROM public.getMyActivity()
);

ALTER VIEW public.MyActivity OWNER TO ClassDB;
GRANT SELECT ON public.MyActivity TO PUBLIC;


COMMIT;
