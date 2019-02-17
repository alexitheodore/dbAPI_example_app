#!/usr/bin/env bash

# exit

echo "starting install script"

vagrant_success_log=/var/setup/vagrant_stty.log
source /var/setup/variables.conf #fills the "vars" variable
source /dbAPI/variables.sh #fills the "pg_vars" variable

sudo timedatectl set-timezone America/New_York

echo "... apt-get update"
sudo apt-get -qq update

# Infrastructure
	sudo mkdir -p ${vars[site_dir]}
	sudo mkdir -p ${vars[site_dir]}/logs
	sudo mkdir -p ${vars[site_dir]}/public

# NGINX
	echo 'Setting up NGINX'

	sudo apt-get -qq -y install nginx

	sudo rm /etc/nginx/sites-available/default
	sudo rm /etc/nginx/sites-enabled/default
	sudo cp /var/setup/nginx.conf /etc/nginx/nginx.conf
		sudo cp /var/setup/default_nginx.conf /etc/nginx/sites-enabled/${vars[site_uri]}.conf
		sudo sed -i "s,{${vars[site_dir]}},${vars[site_dir]}},g" /etc/nginx/sites-enabled/${vars[site_uri]}.conf
		sudo sed -i "s,{${vars[site_uri]}},${vars[site_uri]}},g" /etc/nginx/sites-enabled/${vars[site_uri]}.conf

	echo "... starting NGINX"
	sudo service nginx start

# INSTALL PGS:
	# I believe this is required to be able to properly apt-get postgres
	sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" | \
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
	sudo apt-key add -

	# download
	sudo apt-get update
	sudo apt-get install -y postgresql-9.6 postgresql-contrib-9.6 libpq-dev
	
	sudo service postgresql stop
		sleep 5
	sudo mkdir /home/postgres
	sudo chown postgres:postgres /home/postgres

	# setup pgpass file(s)
	# the local user isn't necessary for the database and though it has the same name as the pg user, its not related
	sudo adduser the_architect --gecos "" --disabled-password --home /home/the_architect/
	echo "the_architect:${vars[pass_the_architect]}" | sudo chpasswd
	sudo su -c "echo \"*:*:*:the_architect:${vars[pass_the_architect]}\" >> /home/the_architect/.pgpass" the_architect
	sudo su -c 'chmod 600 /home/the_architect/.pgpass' the_architect

	sudo service postgresql start

	# firewall setup
	sudo ufw allow ssh
	sudo ufw allow postgresql
	echo 'y' | sudo ufw enable

# SETUP SSH access
	sudo su -c 'echo "AllowUsers the_architect" >> /etc/ssh/sshd_config'

# Initialize DB
	echo "Initializing DB."

	source ${pg_vars[dir_sql_builds]}/sql_init.sh
	# run SQL build scripts (3 times)
	source ${pg_vars[dir_sql_builds]}/sql_build.sh 3

echo 'All done!'