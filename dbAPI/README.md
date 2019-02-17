# Background

The dbAPI acts as the entire data model for the app at large. All database writes, executions and reads happen exclusively through PostgreSQL "delegate functions", which are corresponding endpoints to be consumed by the API.

Each endpoint accepts and returns JSON. Input parameters and outputs are documented below. Not every function has an input or useful response, though every function does return a "return_code", where zero (generic) or positive codes are successful and negative codes are errors, which may include an "error_message".

# Security & Connectivity

The API app should connect to the database using user "prod_rx" and credentials are set passively through the .pgpass file. As a result the API (and beyond) will only have read and execute privileges to the respective endpoints.

The .pgpass file should include the necessary configuration to allow automatic authentication for the prescribed local user. This should be the **only** place that the password is stored on the server (it should not be hard-coded anywhere).

# Examples & Workflow

### Add a new User:

    users.apix_create(
        {
            "email": "you@gmail.com"
        ,   "name_first": "John"
        ,   "name_last": "Doe"
        }
    )

will return '{"return_code":0, ...}' indicating a success and will have created a new user account, and also returning the user's details, as in users.apiv_details(...) (this is simply for convenience).

### Modify a User's details 

    users.apix_update(
        {
            "user_id": 12345
        ,   "name_first": "Jonathan"
        }
    )

will return '{"return_code":0, ...}' indicating a success and will have updated the user account with the keys provided (all else remaining unchanged), and also returning the user's details, as in users.apiv_details(...).

### Set or update a User's password hash

    users.apix_update(
        {
            "user_id": 12345
        ,   "password": "kkr57qz50gsftd1sq62d27q40000gn"
        }
    )

### Retrive a list of Users

This would be for the admin's page to be able to see a list of users and their info.

    users.apiv_dir()

will return an array of users: user_id , email, name_first, name_last.

This function also accepts simple pagination, including "offset" and "limit" options (default is 100 rows).

    users.apiv_dir(
    	{
    		"limit":10
    	,	"offset": 20
    	}
    )

Sorting can be applied by targeting the desired column and direction ("ASC" or "DESC").

    users.apiv_dir(
        {
            "sort_name":"email"
        ,   "sort_dir":"ASC"
        }
    )

Basic filtering by user class is available by specifying class type ("admin" or "client"; default includes both)

    users.apiv_dir(
        {
            "class":"admin"
        }
    )

or active state ("TRUE", "FALSE"; default is TRUE).

    users.apiv_dir(
        {
            "active":"FALSE"
        }
    )

### Retrive User's details

This could be for verifying a password or for displaying account info, etc.

    users.apiv_details(
        {
            "user_id": 12345
        }
    )

will return: user_id , email, user_date, name_first, name_last, class, active, password


# Endpoints


| Function | Request Parameters | Returns | Description |
| --- | --- | --- | --- |
| <!----> users.apix_create | **email** <br> **name_last** <br> **name_first** <br> password | users.apiv_details | Registers a new user in the app. New users are inactive until a password is supplied or they are updated to "active=true" manually.
| <!----> users.apix_update | **user_id** <br> email <br> name_last <br> name_first <br> password | users.apiv_details | Updates a given user's information.
| <!----> users.apiv_details | **user_id** |    user_id <br> email <br> user_date <br> name_first <br> name_last <br> class <br> active | Returns all of a given user's account details.
| <!----> users.apiv_dir | limit <br> offset <br> sort_name <br> sort_dir <br> class <br> active |    user_id <br> email <br> name_first <br> name_last <br> active | Returns an array of all active users.
| <!----> apiv_return_codes | | [return_code <br> desc_detail <br> desc_support <br> desc_customer, ...] | Returns an array of return codes and their respective descriptions. |

***bold** indicates required parameters
<br>
*all functions also return "return_code"

# Building Scipts & Framework
## Background

The database used is PostgreSQL with a heavy reliance on JSONB functionality, especially an extension of JSONB functions and operators made for this purpose. A list with descriptions for the JSON library can be found under the "json_extensions" and "custom_operators" views respectively.

## Building

### Building the database from scratch
Building the database from scratch is completely automated via bash scripting. To do so, first initialize with (only do this once ever):

`$ bash /dbAPI/sql_init.sh`

### Re-building the database
Re-building the database (after making code changes, etc.) run the following command-line script:

`$ bash /dbAPI/sql_build.sh`

The script will do the following operations:

- Rebuild and load the postgresql.conf file from the local source
- Shutdown the database
- Wipe the database clean
- Loop through all the build files in the sql_builds dir (in a specified order)
- Run all functional testing scripts (via functional_testing.sh)
- Reload the database

System-wide variables, such as directory paths, database names, etc. are defined exclusively in the variables.sh file.

### Functional testing

Functional testing is done automatically whenever the database is rebuilt; however, it can and should be done routinely to verify full functionality. Running the following command will do so (all operations and changes are reversed):

`$ bash /dbAPI/functional_testing.sh`
