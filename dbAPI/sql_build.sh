#!/usr/bin/env bash

echo "Beginning SQL build process..."

# Settings
## pgs-specific vars (platform independant)
	source /dbAPI/variables.sh

## set the config file
	sudo cp /dbAPI/postgresql.conf ${pg_vars[dir_pgs_etc]}/postgresql.conf
	for i in "${!pg_vars[@]}"
	do
		sudo sed -i -e 's%{'$i'}%'${pg_vars[$i]}'%g' ${pg_vars[dir_pgs_etc]}/postgresql.conf
	done

# exit

#trust all socket connections temporarily to avoid password entering 
	sudo sed -i '90s/.*/local  all   all    trust/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
	sudo service postgresql restart

#Start from a fresh slate (has to be done in two separate transactions)
	PGOPTIONS='--client-min-messages=warning' psql postgres --command="DROP DATABASE IF EXISTS ${pg_vars[database]};" -U the_architect
	PGOPTIONS='--client-min-messages=warning' psql postgres --command="CREATE DATABASE ${pg_vars[database]} OWNER the_architect ENCODING 'UTF8';" -U the_architect


#Loop-through all of the build files, fill in variables and execute them

	j="0"
	loop_count=${1:-1}

	while [ $j -lt $loop_count ]
	do
		sql_files=(
			refresh.sql
			json_library.sql
			common_functions.sql
			settings.sql
			global.sql
			initial_data.sql

			# <add files here>

			users.sql

			# </add files here>

			permissions.sql
			temp_data.sql
			)

		for sql_file in ${sql_files[@]}
		do
			echo "INFO:  Building: $sql_file"

			# grab file, replace variables
				sql_file="${pg_vars[dir_sql_builds]}/sql_builds/$sql_file"
				
				cp $sql_file $sql_file.tmp
				for i in "${!pg_vars[@]}"
				do
					sed -i -e 's%{'$i'}%'${pg_vars[$i]}'%g' $sql_file.tmp
				done

			PGOPTIONS='--client-min-messages=warning' psql ${pg_vars[database]} < "$sql_file.tmp" --u the_architect -q

			rm $sql_file.tmp

		done
		j=$[$j+1]
	done

echo "Builds successful!"


# Run functional tests (optional)
echo "Running functional tests..."
PGOPTIONS='--client-min-messages=warning' psql ${pg_vars[database]} < "${pg_vars[dir_sql_builds]}/sql_builds/funct_tests.sql" --u the_architect -q

#restore security - set socket connections to validate for local connections with db users
sudo sed -i '90s/.*/local  all   all      md5/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
sudo service postgresql reload