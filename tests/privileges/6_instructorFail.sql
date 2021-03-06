--6_instructorFail.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL)
--https://dassl.github.io/

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--Instructor should not be able to manage roles
SELECT ClassDB.createStudent('teststu_pt', 'testname');
SELECT ClassDB.resetPassword('teststu_pt');
SELECT ClassDB.createTeam('testteam_pt');
SELECT ClassDB.addToTeam('teststu_pt', 'testteam_pt');
SELECT ClassDB.removeFromTeam('teststu_pt', 'testteam_pt');
SELECT ClassDB.revokeTeam('testteam_pt');
SELECT ClassDB.dropTeam('testteam_pt', TRUE, TRUE, 'drop_c');
SELECT ClassDB.revokeStudent('teststu_pt');
SELECT ClassDB.dropStudent('teststu_pt', TRUE, TRUE, 'drop_c');
--ClassDB.dropAllStudents is not being tested here because it would drop the
-- test students that will later be used to connect to the DB
--SELECT ClassDB.dropAllStudents(TRUE, TRUE, 'drop_c');

SELECT ClassDB.createInstructor('testins_pt', 'testname');
SELECT ClassDB.revokeInstructor('testins_pt');
SELECT ClassDB.dropInstructor('testins_pt', TRUE, TRUE, 'drop_c');
SELECT ClassDB.createDBManager('testman_pt', 'noname');
SELECT ClassDB.revokeDBManager('testman_pt');
SELECT ClassDB.dropDBManager('testman_pt', TRUE, TRUE, 'drop_c');
SELECT ClassDB.addToTeam('ptstu0', 'ptteam0');



--Not insert, delete or update from RoleBase table
INSERT INTO ClassDB.RoleBase VALUES('testRole', 'Test name', FALSE,
                                    'Test schema', 'Test info');

DELETE FROM ClassDB.RoleBase
WHERE RoleName = 'ptstu0';

UPDATE ClassDB.RoleBase
SET RoleName = 'diffName'
WHERE RoleName = 'ptstu0';

UPDATE ClassDB.RoleBase
SET IsTeam = TRUE
WHERE RoleName = 'ptstu0';

UPDATE ClassDB.RoleBase
SET SchemaName = 'diffSchema'
WHERE RoleName = 'ptstu0';

UPDATE ClassDB.RoleBase
SET FullName = 'Updated name', ExtraInfo = 'Updated info'
WHERE roleName = 'ptstu0';


--Not insert, update, or delete from DDLActivity and ConnectionActivity tables
INSERT INTO ClassDB.DDLActivity VALUES ('ptstu0', '2000-01-01 00:00',
                                        'CREATE TABLE', 'ptstu0.myTable');

UPDATE ClassDB.DDLActivity
SET DDLOperation = 'DROP TABLE'
WHERE UserName = 'ptstu0';

DELETE FROM ClassDB.DDLActivity
WHERE UserName = 'ptstu0';

INSERT INTO ClassDB.ConnectionActivity VALUES ('ptsu0', '2000-01-01 00:00');

UPDATE ClassDB.ConnectionActivity
SET ActivityAtUTC = '1999-12-31 00:00'
WHERE UserName = 'ptstu0';

DELETE FROM ClassDB.ConnectionActivity
WHERE UserNAme = 'ptstu0';


--Not read other instructor or DB manager tables
SELECT * FROM ptins0.testInsUsr;
SELECT * FROM ptdbm0.testDbmUsr;


--Not execute internal functions
SELECT ClassDB.createRole('testrole', 'Test name', FALSE);
SELECT ClassDB.revokeClassDBRole('ptstu0', 'classdb_student');
SELECT ClassDB.dropRole('ptstu0');
SELECT ClassDB.logDDLActivity();
SELECT ClassDB.rejectOperation();

--Not drop ClassDB tables and views
DROP TABLE ClassDB.DDLActivity;
DROP TABLE ClassDB.RoleBase;
DROP VIEW public.MyActivity;
DROP VIEW ClassDB.StudentActivityAnon;
DROP VIEW ClassDB.StudentActivity;
DROP VIEW public.MyConnectionActivity;
DROP VIEW public.MyDDLActivity;
DROP VIEW ClassDB.User;
DROP VIEW ClassDB.Instructor;
DROP VIEW ClassDB.Student;
DROP VIEW ClassDB.DBManager;
DROP VIEW ClassDB.StudentTable;
DROP VIEW ClassDB.StudentTableCount;
DROP VIEW ClassDB.StudentActivitySummary;
DROP VIEW ClassDB.StudentActivitySummaryAnon;


--Not drop ClassDB functions (also covers ALTER and REPLACE)
DROP FUNCTION IF EXISTS classdb.cancreatedatabase(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.canlogin(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.changetimezone(TIMESTAMP, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS classdb.createdbmanager(ClassDB.IDNameDomain, VARCHAR,
                                                ClassDB.IDNameDomain,VARCHAR,
                                                BOOLEAN, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS classdb.createinstructor(ClassDB.IDNameDomain, VARCHAR,
                                                 ClassDB.IDNameDomain,VARCHAR,
                                                 BOOLEAN, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS classdb.createrole(ClassDB.IDNameDomain, VARCHAR,
                                           BOOLEAN, ClassDB.IDNameDomain,
                                           VARCHAR, BOOLEAN, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS classdb.createstudent(ClassDB.IDNameDomain, VARCHAR,
                                              ClassDB.IDNameDomain,VARCHAR,
                                              BOOLEAN, BOOLEAN, VARCHAR);
DROP FUNCTION IF EXISTS public.describe(VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS public.describe(VARCHAR);
DROP FUNCTION IF EXISTS classdb.disableddlactivitylogging();
DROP FUNCTION IF EXISTS classdb.dropallstudents(BOOLEAN, BOOLEAN, VARCHAR,
                                                ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.dropdbmanager(ClassDB.IDNameDomain, BOOLEAN,
                                              BOOLEAN, VARCHAR,
                                              ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.dropinstructor(ClassDB.IDNameDomain,BOOLEAN,
                                               BOOLEAN, VARCHAR,
                                               ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.droprole(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN,
                                         VARCHAR, ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.dropstudent(ClassDB.IDNameDomain, BOOLEAN,
                                            BOOLEAN, VARCHAR,
                                            ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.enableddlactivitylogging();
DROP FUNCTION IF EXISTS classdb.foldpgid(VARCHAR);
DROP FUNCTION IF EXISTS public.foldpgid(VARCHAR);
DROP FUNCTION IF EXISTS public.getmyactivity();
DROP FUNCTION IF EXISTS public.getmyactivitysummary();
DROP FUNCTION IF EXISTS public.getmyconnectionactivity();
DROP FUNCTION IF EXISTS public.getmyddlactivity();
DROP FUNCTION IF EXISTS classdb.getschemaname(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.getschemaownername(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.getuseractivity(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.getuseractivitysummary(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.getuserconnectionactivity(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.getuserddlactivity(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.hasclassdbrole(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.hascreaterole(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.importconnectionlog(DATE);
DROP FUNCTION IF EXISTS classdb.isclassdbrolename(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isdbmanager(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isinstructor(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.ismember(ClassDB.IDNameDomain,
                                          ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isroleknown(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isserverroledefined(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isstudent(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.issuperuser(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isteam(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isuser(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.killconnection(INT4);
DROP FUNCTION IF EXISTS classdb.killuserconnections(VARCHAR);
DROP FUNCTION IF EXISTS classdb.listorphanobjects(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.listownedobjects(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS public.listtables(VARCHAR);
DROP FUNCTION IF EXISTS classdb.listuserconnections(VARCHAR);
DROP FUNCTION IF EXISTS classdb.logddlactivity();
DROP FUNCTION IF EXISTS classdb.rejectoperation();
DROP FUNCTION IF EXISTS classdb.resetpassword(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.revokeclassdbrole(ClassDB.IDNameDomain,
                                                   ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.revokedbmanager(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.revokeinstructor(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.revokestudent(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.createteam(ClassDB.IDNameDomain,
                                           VARCHAR, ClassDB.IDNameDomain,
                                           VARCHAR, BOOLEAN, BOOLEAN);
DROP FUNCTION IF EXISTS classdb.revoketeam(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.dropteam(ClassDB.IDNameDomain, BOOLEAN, BOOLEAN,
                                         VARCHAR, ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.dropallteams(BOOLEAN, BOOLEAN, VARCHAR,
                                             ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isteammember(ClassDB.IDNameDomain,
                                             ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.addtoteam(ClassDB.IDNameDomain,
                                          ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.removefromteam(ClassDB.IDNameDomain,
                                               ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.removeallfromteam(ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.reassignobjectownership(VARCHAR, VARCHAR,
                                                        ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.reassignownedinschema(ClassDB.IDNameDomain,
                                                      ClassDB.IDNameDomain,
                                                      ClassDB.IDNameDomain);
DROP FUNCTION IF EXISTS classdb.isconnectionloggingenabled();
DROP FUNCTION IF EXISTS classdb.isloggingcollectorenabled();
DROP FUNCTION IF EXISTS classdb.handledropschemaddlstart();
DROP FUNCTION IF EXISTS classdb.disallowschemadrop();
DROP FUNCTION IF EXISTS classdb.allowschemadrop();
DROP FUNCTION IF EXISTS classdb.isschemadropallowed();

 