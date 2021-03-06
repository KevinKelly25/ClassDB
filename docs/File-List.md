[ClassDB Home](Home) \| [Table of Contents](Table-of-Contents)

---
# File List

_Author: Steven Rollo_

This document lists the files located in the ClassDB repository. Each section lists the files in the corresponding folder.

## Root (./)
Contains the README and LICENSE files, as well as each ClassDB sub-folder.
- `LICENSE.md`
- `README.md`

## docs (./docs)
Contains a copy of the ClassDB documentation for the corresponding release. The contents of the docs folder is a copy of the [ClassDB wiki](https://github.com/DASSL/ClassDB/wiki) at the time of release - the wiki holds the current development version of the docs.

## examples (./examples)
Contains script files for the shelter example schema. More information can be found on the [Scripts](Scripts) page.
- `createShelterSchema.sql`
- `dropShelterSchema.sql`
- `populateShelterSchema.sql`

## src (./src)
Contains the source code for ClassDB. All files need to install ClassDB are in this folder. More information can be found on the [Scripts](Scripts) page.
- `./src/`
  - `db/`
    - `addAllToDB.psql`
    - `removeAllFromDB.sql`
    - `core/`
      - `addAllDBCore.psql`
      - `addClassDBRolesMgmtCore.sql`
      - `addClassDBRolesViewsCore.sql`
      - `addHelpersCore.sql`
      - `addRoleBaseMgmtCore.sql`
      - `addServerVersionComparersCore.sql`
      - `addUserMgmtCore.sql`
      - `initializeDBCore.sql`
    - `opt/`
      - `addAllDBOpt.psql`
      - `addCatalogMgmtOpt.sql`
    - `reco/`
      - `addAllDBReco.psql`
      - `addConnectionActivityLoggingReco.sql`
      - `addConnectionMgmtReco.sql`
      - `addDDLActivityLoggingReco.sql`
      - `addDisallowSchemaDropReco.sql`
      - `addFrequentViewsReco.sql`
  - `server/`
    - `addAllToServer.psql`
    - `removeAllFromServer.sql`
    - `core/`
      - `addAllServerCore.psql`
      - `initializeServerCore.sql`
    - `reco/`
      - `addAllServerReco.psql`
      - `assertAlterSystemAvailability.sql`
      - `disableConnectionLoggingReco.psql`
      - `enableConnectionLoggingReco.psql`
      
## tests (./tests)
This folder contains scripts to test the functionality of ClassDB, along with the privileges sub-folder
- `testConnectionActivityLogging.psql`
- `testDDLActivityLogging.sql`
- `testClassDBRolesMgmt.sql`
- `testHelpers.sql`
- `testRoleBaseMgmt.sql`
- `testUserMgmt.sql`

### privileges (./tests/privileges)
This folder contains a sequence of scripts to test the functionality of ClassDB's privilege management
- `0_setup.sql`
- `1_instructorPass.sql`
- `2_studentPass.sql`
- `3_dbmanagerPass.sql`
- `4_instructorPass2.sql`
- `5_instructorFail.sql`
- `6_studentFail.sql`
- `7_dbmanagerFail.sql`
- `8_cleanup.sql`
- `testPrivilegesREADME.txt`

---
