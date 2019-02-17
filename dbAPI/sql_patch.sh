#!/usr/bin/env bash

echo "Beginning SQL patching process..."

# Settings
## pgs-specific vars (platform independant)
	source /dbAPI/variables.sh

#trust all socket connections temporarily to avoid password entering 
	sudo sed -i '90s/.*/local  all   all    trust/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
	sudo service postgresql restart

#Loop-through all of the build files, fill in variables and execute them

	j="0"
	loop_count=${1:-1}

	while [ $j -lt $loop_count ]
	do
		sql_files=(
			patches.sql
			permissions.sql
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

echo "Patches successful!"


# Run functional tests (optional)
echo "Running functional tests..."
PGOPTIONS='--client-min-messages=warning' psql ${pg_vars[database]} < "${pg_vars[dir_sql_builds]}/sql_builds/funct_tests.sql" --u the_architect -q

#restore security - set socket connections to validate for local connections with db users
sudo sed -i '90s/.*/local  all   all      md5/' ${pg_vars[dir_pgs_etc]}/pg_hba.conf
sudo service postgresql reload