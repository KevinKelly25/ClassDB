--initializeDBCore.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run in a database to which ClassDB is to be added
-- the database should have already been created

--This script should be the first to run as part of adding ClassDB to a database

--This script sets up appropriate access controls for the various ClassDB roles
-- it also creates a 'ClassDB' schema to store app-specific data and code


START TRANSACTION;

--Suppress NOTICE messages for this script: won't apply to functions created here
-- hides unimportant but possibly confusing msgs generated as the script executes
SET LOCAL client_min_messages TO WARNING;

--Make sure the current user has sufficient privilege to run this script
-- privilege required: superuser
DO
$$
BEGIN
   IF NOT EXISTS (SELECT * FROM pg_catalog.pg_roles
                  WHERE rolname = CURRENT_USER AND rolsuper = TRUE
                 ) THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user '
                      'with superuser privileges';
   END IF;
END
$$;


--Make sure the expected app-specific roles are already defined:
-- four roles expected: ClassDB, Instructor, DBManager, Student
DO
$$
DECLARE
   classDBRoleCount NUMERIC(1);
BEGIN
   SELECT COUNT(*)
   FROM pg_catalog.pg_roles
   WHERE rolname IN ('classdb', 'classdb_instructor',
                     'classdb_dbmanager', 'classdb_student', 'classdb_team'
                    )
   INTO classDBRoleCount;

   IF classDBRoleCount <> 5 THEN
      RAISE EXCEPTION
         'Missing roles: one or more expected of the expected ClassDB roles '
         'are undefined';
   END IF;
END
$$;

--Prevent users who are not instructors from modifying the public schema
-- public schema contains objects and functions students can read
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO ClassDB_Admin, ClassDB_Instructor;

--Create a schema to hold app's admin info and assign privileges on that schema
CREATE SCHEMA IF NOT EXISTS classdb AUTHORIZATION ClassDB;
GRANT USAGE ON SCHEMA classdb 
      TO ClassDB_Admin, ClassDB_Instructor, ClassDB_DBManager;

--Define a function to grant appropriate privileges to different roles to the 
-- current database This is added so that it can be called again when ClassDB
-- database is used as a template
CREATE OR REPLACE FUNCTION ClassDB.AddUserAccess()
RETURNS VOID AS
$$
DECLARE
   currentDB VARCHAR(128);
BEGIN
   currentDB := current_database();

   --Disallow DB connection to all users
   -- Postgres grants CONNECT to all by default
   EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', currentDB);

   --Let only app-specific roles connect to the DB
   -- no need for ClassDB to connect to the DB
   EXECUTE format('GRANT CONNECT ON DATABASE %I TO ClassDB_Admin, '
                  'ClassDB_Instructor, ClassDB_Student, ClassDB_DBManager'
                  , currentDB);

   --Allow ClassDB and ClassDB users to create schemas on the current database
   EXECUTE format('GRANT CREATE ON DATABASE %I TO ClassDB, ClassDB_Admin, '
                  'ClassDB_Instructor, ClassDB_Student, ClassDB_DBManager'
                  , currentDB);
END;
$$ LANGUAGE plpgsql;


ALTER FUNCTION ClassDB.AddUserAccess() OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.AddUserAccess() FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.AddUserAccess()
      TO ClassDB_Admin;

--Prevent users who are not instructors from modifying the public schema
-- public schema contains objects and functions students can read
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT CREATE ON SCHEMA public TO ClassDB_Admin, ClassDB_Instructor, ClassDB;


--Execute this above function for when script is run for first time on template
-- database
DO
$$
BEGIN
  PERFORM ClassDB.AddUserAccess();
END
$$;


COMMIT;
