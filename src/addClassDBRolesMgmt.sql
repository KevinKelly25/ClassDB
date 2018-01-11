--addClassDBRolesMgmt.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


--This script requires the current user to be a superuser

--This script should be run after addConnectionMgmt.sql

--This script creates views and procedures to interact with ClassDB's user
--management and group roles

START TRANSACTION;

--Suppress NOTICEs for this script only, this will not apply to functions
-- defined within. This hides unimportant, but possibly confusing messages
SET LOCAL client_min_messages TO WARNING;


--Make sure the current user has sufficient privilege to run this script
-- privileges required: superuser
DO
$$
BEGIN
   IF NOT classdb.isSuperUser() THEN
      RAISE EXCEPTION 'Insufficient privileges: script must be run as a user'
                      ' with superuser privileges';
   END IF;
END
$$;



--Define views to obtain info on known instructors, students, and DB managers
-- these views obtain information from the previously defined ClassDB.User view
CREATE OR REPLACE VIEW ClassDB.Instructor AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsStudent, IsDBManager
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsInstructor;

ALTER VIEW ClassDB.Instructor OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Instructor FROM PUBLIC;
GRANT SELECT ON ClassDB.Instructor TO ClassDB_Instructor, ClassDB_DBManager;


CREATE OR REPLACE VIEW ClassDB.Student AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsDBManager
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsStudent;

ALTER VIEW ClassDB.Student OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.Student FROM PUBLIC;
GRANT SELECT ON ClassDB.Student TO ClassDB_Instructor, ClassDB_DBManager;


CREATE OR REPLACE VIEW ClassDB.DBManager AS
   SELECT UserName, FullName, SchemaName, ExtraInfo, IsInstructor, IsStudent
--TBD:    DDLCount, LastDDLOperation, LastDDLObject, LastDDLActivityAtUTC,
--TBD:    ConnectionCount, LastConnectionAtUTC
   FROM ClassDB.User
   WHERE IsDBManager;

ALTER VIEW ClassDB.DBManager OWNER TO ClassDB;
REVOKE ALL PRIVILEGES ON ClassDB.DBManager FROM PUBLIC;
GRANT SELECT ON ClassDB.DBManager TO ClassDB_Instructor, ClassDB_DBManager;



--Define three functions to test is a user is a member of ClassDB's student,
-- instructor, or DB manager roles, respectively
--The result returned is equivalent to calling ClassDB.isMember with the
-- appropriate group role, meaning that even if true, it is not necessarily a
-- "known" role
CREATE OR REPLACE FUNCTION ClassDB.isStudent(userName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.isMember($1, 'ClassDB_Student');
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isStudent(ClassDB.IDNameDomain) OWNER TO ClassDB;


CREATE OR REPLACE FUNCTION ClassDB.isInstructor(userName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.isMember($1, 'ClassDB_Instructor');
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isInstructor(ClassDB.IDNameDomain) OWNER TO ClassDB;


CREATE OR REPLACE FUNCTION ClassDB.isDBManager(userName ClassDB.IDNameDomain)
   RETURNS BOOLEAN AS
$$
   SELECT ClassDB.isMember($1, 'ClassDB_DBManager');
$$ LANGUAGE sql
   STABLE
   RETURNS NULL ON NULL INPUT;

ALTER FUNCTION ClassDB.isDBManager(ClassDB.IDNameDomain) OWNER TO ClassDB;



--Define function to register a student and perform corresponding configuration
--Calls ClassDB.createRole with corresponding parameters
--Grants appropriate privileges to newly established role and schema
CREATE OR REPLACE FUNCTION
   ClassDB.createStudent(userName ClassDB.IDNameDomain,
                         fullName ClassDB.RoleBase.FullName%Type,
                         schemaName ClassDB.IDNameDomain DEFAULT NULL,
                         extraInfo ClassDB.RoleBase.ExtraInfo%Type DEFAULT NULL,
                         okIfRoleExists BOOLEAN DEFAULT TRUE,
                         okIfSchemaExists BOOLEAN DEFAULT TRUE,
                         initialPwd VARCHAR(128) DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
   --record ClassDB role
   PERFORM ClassDB.createRole($1, $2, FALSE, $3, $4, $5, $6, $7);

   --get name of role's schema (possibly not the original value of schemaName)
   $3 = ClassDB.getSchemaName($1);

   --grant server-level student group role to new student
   EXECUTE FORMAT('GRANT ClassDB_Student TO %s', $1);

   --set server-level client connection settings for the student
   EXECUTE FORMAT('ALTER ROLE %s CONNECTION LIMIT 5', $1);
   EXECUTE FORMAT('ALTER ROLE %s SET statement_timeout = 2000', $1);

   --grant instructors privileges to the student's schema
   EXECUTE FORMAT('GRANT USAGE ON SCHEMA %s TO ClassDB_Instructor', $3);
   EXECUTE FORMAT('GRANT SELECT ON ALL TABLES IN SCHEMA %s TO'
                  ' ClassDB_Instructor', $3);
   EXECUTE FORMAT('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA %s'
                  ' GRANT SELECT ON TABLES TO ClassDB_Instructor', $1, $3);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.createStudent(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                         ClassDB.IDNameDomain, ClassDB.RoleBase.ExtraInfo%Type,
                         BOOLEAN, BOOLEAN, VARCHAR(128))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.createStudent(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                         ClassDB.IDNameDomain, ClassDB.RoleBase.ExtraInfo%Type,
                         BOOLEAN, BOOLEAN, VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.createStudent(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                         ClassDB.IDNameDomain, ClassDB.RoleBase.ExtraInfo%Type,
                         BOOLEAN, BOOLEAN, VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define function to unregister a student and undo student configurations
CREATE OR REPLACE FUNCTION ClassDB.revokeStudent(userName ClassDB.IDNameDomain)
   RETURNS VOID AS
$$
BEGIN
   --revoke student server-level role
   PERFORM ClassDB.revokeClassDBRole($1, 'ClassDB_Student');

   --reset server-level client connection settings for the role to defaults
   -- no default option available for CONNECTION LIMIT (-1 disables the limit)
   EXECUTE FORMAT('ALTER ROLE %s SET statement_timeout TO DEFAULT', $1);
   EXECUTE FORMAT('ALTER ROLE %s CONNECTION LIMIT -1', $1);

   --revoke privileges from instructors to the role's schema
   EXECUTE FORMAT('REVOKE USAGE ON SCHEMA %s FROM ClassDB_Instructor',
                  ClassDB.getSchemaName($1));
   EXECUTE FORMAT('REVOKE SELECT ON ALL TABLES IN SCHEMA %s FROM'
               ||' ClassDB_Instructor', ClassDB.getSchemaName($1));
   EXECUTE FORMAT('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA %s REVOKE'
               ||' SELECT ON TABLES FROM ClassDB_Instructor', $1,
                 ClassDB.getSchemaName($1));
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION ClassDB.revokeStudent(ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.revokeStudent(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.revokeStudent(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to drop a student
CREATE OR REPLACE FUNCTION
   ClassDB.dropStudent(userName ClassDB.IDNameDomain,
                       dropFromServer BOOLEAN DEFAULT FALSE,
                       okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                       objectsDisposition VARCHAR DEFAULT 'assign_i',
                       newObjectsOwnerName ClassDB.IDNameDomain DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
    --revoke student role (also asserts that userName corresponds to a student)
    PERFORM ClassDB.revokeStudent($1);

    --drop student
    PERFORM ClassDB.dropRole($1, $2, $3, $4, $5);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.dropStudent(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                       ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.dropStudent(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                       ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.dropStudent(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                       ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to drop all students
CREATE OR REPLACE FUNCTION
   ClassDB.dropAllStudents(dropFromServer BOOLEAN DEFAULT FALSE,
                           okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                           objectsDisposition VARCHAR DEFAULT 'assign_i',
                           newObjectsOwnerName ClassDB.IDNameDomain
                                               DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
   PERFORM ClassDB.dropStudent(S.RoleName, $1, $2, $3, $4)
   FROM ClassDB.Student S;
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION ClassDB.dropAllStudents(VARCHAR, ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.dropAllStudents(VARCHAR, ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.dropAllStudents(VARCHAR, ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define function to register an instructor and perform corresponding config
--Calls ClassDB.createRole with corresponding parameters
--Grants appropriate privileges to newly established role and schema
CREATE OR REPLACE FUNCTION
   ClassDB.createInstructor(userName ClassDB.IDNameDomain,
                            fullName ClassDB.RoleBase.FullName%Type,
                            schemaName ClassDB.IDNameDomain DEFAULT NULL,
                            extraInfo ClassDB.RoleBase.ExtraInfo%Type
                                      DEFAULT NULL,
                            okIfRoleExists BOOLEAN DEFAULT TRUE,
                            okIfSchemaExists BOOLEAN DEFAULT TRUE,
                            initialPwd VARCHAR(128) DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
   --record ClassDB role
   PERFORM ClassDB.createRole($1, $2, FALSE, $3, $4, $5, $6, $7);

   --grant server-level instructor group role to new instructor
   EXECUTE FORMAT('GRANT ClassDB_Instructor TO %s', $1);

   --set privileges on future tables the instructor creates in 'public' schema
   EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA public GRANT'
               || ' SELECT ON TABLES TO PUBLIC', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.createInstructor(ClassDB.IDNameDomain,
                            ClassDB.RoleBase.FullName%Type,
                            ClassDB.IDNameDomain,
                            ClassDB.RoleBase.ExtraInfo%Type,
                            BOOLEAN, BOOLEAN, VARCHAR(128))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.createInstructor(ClassDB.IDNameDomain,
                            ClassDB.RoleBase.FullName%Type,
                            ClassDB.IDNameDomain,
                            ClassDB.RoleBase.ExtraInfo%Type,
                            BOOLEAN, BOOLEAN, VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.createInstructor(ClassDB.IDNameDomain,
                            ClassDB.RoleBase.FullName%Type,
                            ClassDB.IDNameDomain,
                            ClassDB.RoleBase.ExtraInfo%Type,
                            BOOLEAN, BOOLEAN, VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define function to unregister an instructor and undo instructor configurations
CREATE OR REPLACE FUNCTION
   ClassDB.revokeInstructor(userName ClassDB.IDNameDomain)
   RETURNS VOID AS
$$
BEGIN
   --revoke server-level instructor group role
   PERFORM ClassDB.revokeClassDBRole($1, 'ClassDB_Instructor');

   --reset privileges on future tables the instructor creates in 'public' schema
   EXECUTE format('ALTER DEFAULT PRIVILEGES FOR ROLE %s IN SCHEMA public REVOKE'
               || ' SELECT ON TABLES FROM PUBLIC', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION ClassDB.revokeInstructor(ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.revokeInstructor(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.revokeInstructor(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to drop an instructor
CREATE OR REPLACE FUNCTION
   ClassDB.dropInstructor(userName ClassDB.IDNameDomain,
                          dropFromServer BOOLEAN DEFAULT FALSE,
                          okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                          objectsDisposition VARCHAR DEFAULT 'assign_i',
                          newObjectsOwnerName ClassDB.IDNameDomain DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
    --revoke instructor role (also asserts that userName is an instructor)
    PERFORM ClassDB.revokeInstructor($1);

    --drop instructor
    PERFORM ClassDB.dropRole($1, $2, $3, $4, $5);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.dropInstructor(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                          ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.dropInstructor(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                          ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.dropInstructor(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                          ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define function to register a DB manager and perform corresponding config
--Calls ClassDB.createRole with corresponding parameters
--Grants appropriate privileges to newly established role and schema
CREATE OR REPLACE FUNCTION
   ClassDB.createDBManager(userName ClassDB.IDNameDomain,
                           fullName ClassDB.RoleBase.FullName%Type,
                           schemaName ClassDB.IDNameDomain DEFAULT NULL,
                           extraInfo ClassDB.RoleBase.ExtraInfo%Type
                                     DEFAULT NULL,
                           okIfRoleExists BOOLEAN DEFAULT TRUE,
                           okIfSchemaExists BOOLEAN DEFAULT TRUE,
                           initialPwd VARCHAR(128) DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
   --record ClassDB role
   PERFORM ClassDB.createRole($1, $2, FALSE, $3, $4, $5, $6, $7);

   --grant server-level DB manager group role to new DB manager
   EXECUTE FORMAT('GRANT ClassDB_DBManager TO %s', $1);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.createDBManager(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                           ClassDB.IDNameDomain,
                           ClassDB.RoleBase.ExtraInfo%Type,
                           BOOLEAN, BOOLEAN, VARCHAR(128))
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.createDBManager(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                           ClassDB.IDNameDomain,
                           ClassDB.RoleBase.ExtraInfo%Type,
                           BOOLEAN, BOOLEAN, VARCHAR(128))
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.createDBManager(ClassDB.IDNameDomain, ClassDB.RoleBase.FullName%Type,
                           ClassDB.IDNameDomain,
                           ClassDB.RoleBase.ExtraInfo%Type,
                           BOOLEAN, BOOLEAN, VARCHAR(128))
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define function to unregister a DB manager and undo DB manager configurations
CREATE OR REPLACE FUNCTION
   ClassDB.revokeDBManager(userName ClassDB.IDNameDomain)
   RETURNS VOID AS
$$
BEGIN
   --revoke server-level DB manager group role
   PERFORM ClassDB.revokeClassDBRole($1, 'ClassDB_DBManager');
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION ClassDB.revokeDBManager(ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION ClassDB.revokeDBManager(ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION ClassDB.revokeDBManager(ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



--Define a function to drop a DB manager
CREATE OR REPLACE FUNCTION
   ClassDB.dropDBManager(userName ClassDB.IDNameDomain,
                         dropFromServer BOOLEAN DEFAULT FALSE,
                         okIfRemainsClassDBRoleMember BOOLEAN DEFAULT TRUE,
                         objectsDisposition VARCHAR DEFAULT 'assign_i',
                         newObjectsOwnerName ClassDB.IDNameDomain DEFAULT NULL)
   RETURNS VOID AS
$$
BEGIN
    --revoke DB manager role (also asserts that userName is a DB manager)
    PERFORM ClassDB.revokeDBManager($1);

    --drop DB manager
    PERFORM ClassDB.dropRole($1, $2, $3, $4, $5);
END;
$$ LANGUAGE plpgsql
   SECURITY DEFINER;


--Change function ownership and set permissions
ALTER FUNCTION
   ClassDB.dropDBManager(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                         ClassDB.IDNameDomain)
   OWNER TO ClassDB;

REVOKE ALL ON FUNCTION
   ClassDB.dropDBManager(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                         ClassDB.IDNameDomain)
   FROM PUBLIC;

GRANT EXECUTE ON FUNCTION
   ClassDB.dropDBManager(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN, VARCHAR,
                         ClassDB.IDNameDomain)
   TO ClassDB_Instructor, ClassDB_DBManager;



COMMIT;
