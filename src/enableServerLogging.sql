--enableServerLogging.sql - ClassDB

--Andrew Figueroa, Steven Rollo, Sean Murthy
--Data Science & Systems Lab (DASSL), Western Connecticut State University (WCSU)

--(C) 2017- DASSL. ALL RIGHTS RESERVED.
--Licensed to others under CC 4.0 BY-SA-NC
--https://creativecommons.org/licenses/by-nc-sa/4.0/

--PROVIDED AS IS. NO WARRANTIES EXPRESSED OR IMPLIED. USE AT YOUR OWN RISK.

--This script must be run as superuser.
--This script must be run after initalizeDB.sql and before addLogMgmt.sql

--Additonally, this script must be run using a client that will send each statement
-- individually, such as psql.  Some clients, like pgAdmin 4, cannot run this script
-- because they pack each statement into a single command string.  This causes
-- ALTER SYSTEM statements to fail.

--This script uses ALTER SYSTEM statements to change the Postgres server log settings for
-- the connection logging system. These statements must be run as superuser, but
-- can't be run inside a TRANSACTION block, however they will still fail if they
-- are run with insufficient permissions.

--The following changes are made:
-- log_connections TO 'on' causes user connections to the DBMS to be reported in
-- the log file
--log_destination TO 'csvlog' cause the logs to be recorded in a csv format,
-- making it possible to use the COPY statement on them
--log_filename sets the log file name. %m and %d are placeholders for month and
-- day respectively, ie. the log file name on June 10th would be postgresql-06.10.
ALTER SYSTEM SET log_connections TO 'on';
ALTER SYSTEM SET log_destination TO 'csvlog';
ALTER SYSTEM SET log_filename TO 'postgresql-%m.%d.log';

START TRANSACTION;

--Check for superuser
DO
$$
BEGIN
   IF NOT (SELECT classdb.isSuperUser()) THEN
      RAISE EXCEPTION 'Insufficient privileges for script: must be run as a superuser';
   END IF;
END
$$;

--We are running pg_reload_conf() in a transaction block so we don't extraneously
-- reload the settings.

--pg_reload_conf() reloads the postgres setting so the changes from ALTER SYSTEM
-- statements apply without having to restart the server
SELECT pg_reload_conf();

COMMIT;
