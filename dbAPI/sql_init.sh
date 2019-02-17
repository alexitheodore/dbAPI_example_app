#!/usr/bin/env bash

# Settings
## pgs-specific vars (platform independant)
	source /dbAPI/variables.sh

pgs_init="${pg_vars[dir_sql_builds]}/sql_builds/pgs_init.sql"
cp $pgs_init $pgs_init.tmp
for i in "${!pg_vars[@]}"
do
	sed -i -e 's%{'$i'}%'${pg_vars[$i]}'%g' $pgs_init.tmp
done

sudo su -c "psql --file=$pgs_init.tmp" postgres
rm $pgs_init.tmp