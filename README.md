# Intro

This is a simple demonstration of a PostgreSQL-based "dbAPI" implementation. It is a structured framework for formalizing the database as an API server by funneling client activity through stored procedures. 

These "delegate functions" are the singular avenue for all database requests (reading, writing and executing), accepting structured requests and returning structured, reliable responses. In doing so, the entire data model is abstracted from the main application

In order for a proper and full implementation, only the following conditions must be met:

1. **Strictly all interaction by any and all clients must be done exclusively through prescribed “delegate functions” in the database. In other words, there is absolutely no literal SQL code employed in any way outside of the database (no ORM, no queries).** This should be doubly enforced by user permissions in condition #3.
1. **Delegate functions accept and return data in a structured and standardized form.** For example, in a Node environment, the delegate function would accept and/or return JSON unless specifically (and rarely) desired otherwise.
1. **Dedicated user accounts are made for access to the database and have restricted privileges: only access to delegate functions. These accounts are used for all client connections.** Effectively, the delegate functions are the security layer and are responsible for what reading and writing power is granted to the client. There may be one or more security layers (and respective user accounts) as desired.




# Contents
This demonstration creates a VM using Vagrant, initializes Ubuntu, Postgres 9.6 and NGINX (just in case?). Everything of which (except for Postgres) is an arbitrary preference.

With a VM spun up, the database is built using the provisioning script dbAPI/sql_build.sh. This begins with setting up the postgres config file and then destroying and building the database from scratch, then proceed to execute select files in the dbAPI/sql_builds/ folder, in a specified order. After successfully building, functional tests are executed via dbAPI/sql_build/funct_tests.sql.

For this particular example, "global.sql" and "users.sql" are the only application-specific sql build files. The remaining sql build files are for the standard infrastructure, as follows:

**refresh.sql** - The standard build configuration for Postgres. *
*note: users are created only once and are not destroyed when any related database is dropped.*

**json_library.sql** - A custom JSON extension library that enhances Postgres' basic JSON capability. *
*note: this demonstration makes prolific use of custom/handy JSON operators. For a list of custom operators, see the "custom_operators" view*

**common_functions.sql** - A collection of handy/essential functions - some of which are dependancies, others of which are likely to be required or handy at some point.

**settings.sql** - Various components for system-wide settings/options/categories/etc.; includes tables for Return Code classifications.

**initial_data.sql** - Seeds the database with any initial data, if desired.

**permissions.sql** - Automates the process of scanning the database for api* functions and giving them appropriate permissions.
**note: the convention employed in this example is for delegate functions to be prefixed by "api" where apix_ and apiv_ refer to functions that either execute (write) or view (read) data respectively.*

**temp_data.sql** - For any temp data which is handy in troublshooting or testing.


# Usage

**To build using Vagrant**, navigate to the ../vagrant/ folder and
> $ vagrant up

The vagrant provisioning script should do the rest and you'll have to troubleshoot on your own to figure out any issues.

**After making any changes** (for example to users.sql), the database must be rebuilt. In the ../dbAPI/ folder
> $ bash sql_build.sh

**To add a new sql build file**, reference it by name in the designated loop area inside sql_build.sh

	# <add files here>

	users.sql
	new_file_here.sql

	# </add files here>
	
