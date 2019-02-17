/*
This routine goes through all the existing functions and identifies those that are intended to 
be publically accessible (apiv_* or apix_*) and sets everything up for them automatically. This includes
first allowing access to the appropriate schemas, then granting execution of each function and adding the 
security definer clause so that those functions can be executed without needing to extend any other 
privilages.
*/


CREATE OR REPLACE FUNCTION set_api_permissions() RETURNS VOID AS
$$
DECLARE
	each_function 	TEXT;
	schemas			TEXT;
	domains			TEXT;
BEGIN


-- clear out all privileges to start things from a clean slate
REASSIGN OWNED BY admin_rwx, prod_rx TO the_architect;


select
	string_agg(schema_name,',') into schemas
from information_schema.schemata
where
	schema_owner = 'the_architect'
;
select
	string_agg(domain_name,', ') into domains
from information_schema.domains
where
	domain_schema = 'global'
;

execute 
		'GRANT ALL ON ALL TABLES IN SCHEMA' & schemas & 'to admin_rwx, prod_rx;'
	&	'GRANT ALL ON ALL SEQUENCES IN SCHEMA' & schemas & 'to admin_rwx, prod_rx;'
	&	'GRANT ALL ON DOMAIN' & domains & 'to admin_rwx, prod_rx;'
	&	'GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA '& schemas &'to admin_rwx, prod_rx;'
	&	'GRANT USAGE ON SCHEMA'& schemas &'to admin_rwx, prod_rx;'
;


-- ALLOW apiv_ and apix_ functions execution:
FOR each_function IN (
-- 
with
	base as
(
SELECT 
	routines.routine_name
,	parameters.data_type
,	parameters.ordinal_position
,	routines.specific_schema
,	parameter_mode

FROM information_schema.routines
left JOIN information_schema.parameters using (specific_name)
WHERE 
	(	routines.routine_name like 'apiv_%'
	OR 	routines.routine_name like 'apix_%'
	)
	OR	routines.routine_name <@ '{setting_update}'

)
,	report as
(
select
	specific_schema
,	routine_name
,	COALESCE(string_agg(data_type, ', ' order by ordinal_position) FILTER (WHERE (parameter_mode = 'IN' OR parameter_mode IS NULL)) ,'') as args
from base
group by specific_schema, routine_name
)
select
	specific_schema||'."'||routine_name ||'"('|| args || ')'
from report

--

) LOOP

	execute 
	'	GRANT EXECUTE ON FUNCTION '|| each_function ||' to admin_rwx, prod_rx, testing_rx;
		ALTER FUNCTION '|| each_function ||' SECURITY DEFINER;
	';

END LOOP;


-- ALLOW operator functions to be used:
FOR each_function IN (
-- 
SELECT
	'"'||prc.proname ||'"('|| array_to_string(array[lt.typname,rt.typname],',') || ')'
FROM pg_operator op
LEFT JOIN pg_namespace ns ON ns.oid = op.oprnamespace
LEFT JOIN pg_type lt ON lt.oid = op.oprleft
LEFT JOIN pg_type rt ON rt.oid = op.oprright
LEFT JOIN pg_proc prc ON prc.oid = op.oprcode
WHERE
	ns.nspname = 'global'
and prc.proname IS NOT NULL


--

) LOOP

	execute 
	'	GRANT EXECUTE ON FUNCTION '|| each_function ||' to admin_rwx, prod_rx, testing_rx;
		-- ALTER FUNCTION '|| each_function ||' SECURITY DEFINER
		;
	';

END LOOP;


END;
$$
LANGUAGE PLPGSQL
VOLATILE
;


CREATE OR REPLACE VIEW user_priviledges AS
with
	base as
(
select
	privilege_type & 'ON' & table_schema ||'.'||column_name & 'TO' & grantee
,	privilege_type
,	grantee
from information_schema.column_privileges

UNION

select
	privilege_type & 'ON' & specific_schema ||'.'||routine_name & 'TO' & grantee
,	privilege_type
,	grantee
from information_schema.routine_privileges

UNION

select
	privilege_type & 'ON' & table_schema ||'.'||table_name & 'TO' & grantee
,	privilege_type
,	grantee
from information_schema.table_privileges

UNION

select
	privilege_type & 'ON' & udt_schema ||'.'||udt_name & 'TO' & grantee
,	privilege_type
,	grantee
from information_schema.udt_privileges

UNION

select
	privilege_type & 'ON' & object_schema ||'.'||object_name & 'TO' & grantee
,	privilege_type
,	grantee
from information_schema.usage_privileges

order by grantee, privilege_type
)

select
	*
from base

;


DO $$
BEGIN

PERFORM set_api_permissions();

END;
$$
LANGUAGE PLPGSQL
;