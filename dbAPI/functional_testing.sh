#!/usr/bin/env bash

## pgs-specific vars (platform independant)
	source /dbAPI/variables.sh

## server-specific vars (platform dependant)
	source ${pg_vars[setup_vars]}

#trust all socket connections temporarily to avoid password entering 
sudo sed -i '90s/.*/local  all   all    trust/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
sudo service postgresql restart

# sudo rm -Rf /www/files/uploads/tmp_*
# sudo cp -Rf /www/files/uploads/funct_testing_source /www/files/uploads/tmp_temp_image
# sudo cp -Rf /www/files/uploads/funct_testing_source /www/files/uploads/tmp_funct_testing
# sudo chown -R postgres /www/files/uploads/tmp_*

psql ${pg_vars[database]} < "${pg_vars[dir_sql_builds]}/sql_builds/funct_tests.sql" --u the_architect -q


#set socket connections to validate for local connections with db users
sudo sed -i '90s/.*/local  all   all      md5/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
sudo service postgresql reload
