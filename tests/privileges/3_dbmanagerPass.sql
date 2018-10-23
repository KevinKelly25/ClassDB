--3_dbmanagerPass.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.


START TRANSACTION;

--Execute appropriate ClassDB functions (these tests do not verify correctness
-- of each function)
SELECT ClassDB.listUserConnections('teststu_pt');
SELECT ClassDB.killUserConnections('teststu_pt');

SELECT ClassDB.importConnectionLog();


--CRUD on tables created by the DBManager. This table should be placed in their
-- own schema and be accessed without needing to be fully schema qualified
--Create without schema qualification
CREATE TABLE Test
(
   col1 VARCHAR(10)
);

--Insert with schema qualification - ensures test was created in the ptdbm0 schema
INSERT INTO ptdbm0.Test VALUES ('hello');

SELECT * FROM Test;

UPDATE Test
SET col1 = 'goodbye';

DELETE FROM Test;
DROP TABLE Test;

--Create and drop schema
CREATE SCHEMA ptdbm0schema;
DROP SCHEMA ptdbm0schema;


--Read from columns in RoleBase table
SELECT * FROM ClassDB.RoleBase;


--Read from columns in User, Student, Instructor, and DBManager views
SELECT * FROM ClassDB.User;
SELECT * FROM ClassDB.DBManager;
SELECT * FROM ClassDB.Student;
SELECT * FROM ClassDB.Instructor;

--Read from public frequent views
SELECT * FROM public.myActivitySummary;
SELECT * FROM public.MyDDLActivity;
SELECT * FROM public.MyConnectionActivity;
SELECT * FROM public.myActivity;


--Read on tables in public schema created by Instructor (should return 1 row)
SELECT * FROM public.testInsPublic;


--Create table in $user schema to test non-access for other roles
CREATE TABLE testDbmUsr
(
   col1 VARCHAR(20)
);

INSERT INTO testDbmUsr VALUES('Read by: ptdbm0');

COMMIT;
