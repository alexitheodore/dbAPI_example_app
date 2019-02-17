#!/usr/bin/env bash

declare -A pg_vars
pg_vars=(
	[database]=cfd_1_0
	[env]=dev
	[dir_pgs_etc]=/etc/postgresql/9.6/main
	[dir_sql_builds]=/dbAPI
	[pass_the_architect]=$(cat ${vars[site_dir]}/security/the_architect.pass)
	[pass_admin_rwx]=$(cat ${vars[site_dir]}/security/admin_rwx.pass)
	[pass_prod_rx]=$(cat ${vars[site_dir]}/security/prod_rx.pass)
	[db_owner]=postgres
)