DROP SCHEMA IF EXISTS testing CASCADE;
CREATE SCHEMA testing;

GRANT USAGE ON SCHEMA testing to testing_rx, prod_rx;
GRANT SELECT ON ALL TABLES IN SCHEMA testing to testing_rx, prod_rx;
GRANT REFERENCES ON ALL TABLES IN SCHEMA testing to testing_rx, prod_rx;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA testing to testing_rx, prod_rx;

/*
----------
	||	 
	||	 
	||	 
*/
CREATE TABLE testing.funct_tests 
(
	id				TEXT	PRIMARY KEY
,	exec_order		SERIAL
,	sql_code		TEXT	NOT NULL
,	sql_checker		TEXT
,	rollback_point	TEXT	NOT NULL DEFAULT ''
,	pg_user			NAME 	CHECK(pg_user IN ('testing_rx', 'testing_rwx')) DEFAULT 'testing_rx'
)
;



/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION testing.exec_funct_tests(IN flags JSONB DEFAULT '{}') returns JSONB AS
$$
DECLARE
	funct_test		RECORD;
	report			JSONB;
	errors			JSONB;
	test_result 	JSONB;
	check_pass		BOOLEAN;
	savepoint		TEXT;
	transcript		TEXT;
	exec_code		TEXT;
	pg_user_name 	NAME;

BEGIN

/*
This function goes through the testing.funct_tests table and executes each test SQL code. The SQL is executed and the results are sequentially appended to a global transcript where they can be referenced at another time by any future test as variables in the SQL that will be filled in prior to execution. If the execution test fails, the SQL error is captured in a report. Otherwise, each test response is evaluated based on a supplied test. If the result of that test is FALSE, the error is captured in a report. Lastly, each test is preceeded by a transaction snapshot. If specified, after a test execution is run, the transaction can be rolled back to any prior transaction, as specified.
*/

errors := '[]';

<<clear>>
BEGIN
	perform dblink_disconnect('funct_tests');
EXCEPTION when others THEN
	EXIT clear;

END;

perform dblink_connect('funct_tests','dbname='||current_database()||' user=the_architect');

-- initializing; these are used throughout the function
exec_code := 
	'ROLLBACK; BEGIN;'
||	'GRANT prod_rx to testing_rx' -- the testing user(s) only have permissions during tests. The rest of the time, they have no permissions.
;

transcript := exec_code;

perform dblink_exec('funct_tests', exec_code); -- put everything to follow inside a transaction block

FOR funct_test in (
	SELECT * FROM testing.funct_tests 
	WHERE 
		(CASE 
			WHEN flags?'id_pattern' THEN
				id like flags->>'id_pattern'
			ELSE TRUE
		END
		)
	ORDER By exec_order
	)
LOOP

transcript := transcript || chr(10) || chr(10) || '-- ' || funct_test.id;

RAISE INFO 'Test: %', funct_test.id;

-- each test begins with a savepoint named for it
savepoint := 'SAVEPOINT funct_test_'||funct_test.exec_order||';';

-- replace variables
funct_test.sql_code := replace_variables(funct_test.sql_code,report);

-- execute test code
BEGIN
	-- pg_user_name := funct_test.pg_user;
	-- SET LOCAL ROLE pg_user_name; -- set the designated role to be executing the tests
	exec_code := 
			savepoint || chr(10) -- start with the savepoint
		||	'SET SESSION ROLE ' || funct_test.pg_user || ';' || chr(10)
		||	trim(both chr(10) from funct_test.sql_code); -- this is the code to execute
	transcript := transcript || chr(10) || exec_code; -- append it to the transcript log

	select * INTO test_result from dblink ('funct_tests', exec_code) as f(json_out JSONB); -- execute

	transcript := transcript || chr(10) || 'return code: ' || COALESCE(test_result->>'return_code', 'NO RESULT');

	report := report & (funct_test.id+>test_result); 

	EXCEPTION when others THEN 
		RAISE INFO 
			'⤷ FAILED TEST EXEC.% %'
		,	chr(10)||'SQL Code: ' || funct_test.sql_code
		,	chr(10)||'SQL Error: ' || SQLERRM
		;
		errors := jsonb_array_append(errors,(funct_test.id+>(('SQL ERROR'+>SQLERRM)&('SQL'+>funct_test.sql_code))));
		exec_code := 'ROLLBACK TO  ' || savepoint;
		transcript := transcript || chr(10) || exec_code || ' -- SQL ERROR!';

		perform dblink_exec('funct_tests', exec_code);
-- 		⤷ ROLLBACK if there was an error
		report := report & (funct_test.id+>'NO RESULT');
		return ('report'+>report)&('errors'+>errors)&('transcript'+>transcript); --continue; 
-- 		⤷ skip everything else if the test itself had an exec error
END;

-- execute return check
<<return_check>>
BEGIN

	IF funct_test.sql_checker IS NULL THEN 
		report := jsonb_insert(report, array[funct_test.id::TEXT,'check_pass'], to_jsonb('NO TEST SPECIFIED'::text));
	--	⤷ you don't always have to check the results for the test to be useful/successful

		-- exec_code := '; ROLLBACK TO  ' || savepoint; -- not sure why I did this?
		-- transcript := transcript || chr(10) || exec_code;

		-- perform dblink_exec('funct_tests', exec_code);
		exit return_check;
	END IF;

	-- build the check code by replacing the %return% placeholder with the test results JSON
	funct_test.sql_checker := replace(funct_test.sql_checker, '%return%', quote_literal(COALESCE(test_result,'{}'))||'::JSONB');
	
	-- build exec_code and transcript 
	exec_code := trim(both chr(10) from funct_test.sql_checker);
	transcript := transcript || chr(10) || exec_code;

	-- run the check code and collect the boolean result
	select * INTO check_pass from dblink ('funct_tests', exec_code) as f(check_pass BOOLEAN);

	-- when a check fails:
	IF check_pass IS NOT TRUE THEN
		RAISE INFO 
			'⤷ FAILED CHECK.% % %'
		,	chr(10)||'SQL TEST Code: ' || funct_test.sql_code
		,	chr(10)||'SQL CHECK Code: ' || funct_test.sql_checker
		,	chr(10)||'SQL CHECK Result: ' || test_result::text
		;

		errors := jsonb_array_append(errors, ('id'+>funct_test.id) & ('check_pass'+>'FAILED TEST!') & ('check SQL'+>to_jsonb(funct_test.sql_checker)) & ('test SQL'+>to_jsonb(funct_test.sql_code)) & (test_result#'return_code'));
		return ('report'+>report)&('errors'+>errors)&('transcript'+>transcript); --continue; 
	END IF;

	report := jsonb_insert(report, array[funct_test.id::TEXT,'check_pass'], to_jsonb((check_pass = TRUE)?'{PASSED,FAILED}'));

	-- when the check itself errors out:
	EXCEPTION when others THEN 
		RAISE INFO 
			'⤷ FAILED CHECK EXEC.% %'
		,	chr(10)||'SQL Code: ' || funct_test.sql_code
		,	chr(10)||'SQL Error: ' || SQLERRM
		;

		errors := jsonb_array_append(errors, ('check_pass'+>SQLERRM)&('SQL'+>funct_test.sql_checker));
		report := jsonb_insert(report, array[funct_test.id::text,'check_pass'], to_jsonb('SQL ERROR'::text));

		exec_code := 'ROLLBACK TO ' || savepoint;
		transcript := transcript || chr(10) || exec_code;

		perform dblink_exec('funct_tests', exec_code);
-- 		⤷ ROLLBACK if there was an error

END; -- end of check code


-- if a rollback is specified, then do so:
IF funct_test.rollback_point != '' THEN 

	exec_code := 'ROLLBACK TO SAVEPOINT funct_test_' || (SELECT exec_order from testing.funct_tests where id = funct_test.rollback_point)||';';
	transcript := transcript || chr(10) || exec_code;

	perform dblink_exec('funct_tests',exec_code); 
-- 		⤷ ROLLBACK here if required
END IF;

END LOOP;


IF empty(flags->'pause') THEN 
	exec_code := 'ROLLBACK;'; 
	transcript := transcript || chr(10) || exec_code;
	perform dblink_exec('funct_tests', exec_code);
ELSE
END IF;


perform dblink_disconnect('funct_tests');

return ('report'+>report)&('errors'+>errors)&('transcript'+>transcript);

END;
$$
LANGUAGE PLPGSQL
VOLATILE
;


DELETE FROM testing.funct_tests;


--> Bookmark ft_functional_test_system
INSERT INTO testing.funct_tests (id, sql_code, sql_checker, rollback_point, pg_user) VALUES


-- (
-- 	'functional_test_name'
-- ,	$sql_code$

-- 	$sql_code$
-- ,	$sql_check$

-- 	$sql_check$
-- ,	'rollback_point (functional_test_name)'
	-- optional*
	-- occurs AFTER the check code is run
-- ,	'exec_user: testing_rx | prod_rx | dev_rx'
-- )




/*
funct TESTING (tests the funct testing system before anything else)
*/
(
	'funct_testing/1/basic' -- test basic functionality of sql test
,	$sql_code$
select 'test'+>'success';
	$sql_code$
,	$sql_check$
select (%return%->>'test') = 'success'
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'funct_testing/1/rollback/1' -- check basic functionality of an execution BEFORE a rollback
,	$sql_code$
select 'new_setting'+>setting_update('testing.dummy','rollback');
	$sql_code$
,	$sql_check$
select ?'testing.dummy' = 'rollback'
	$sql_check$
,	'funct_testing/1/rollback/1'
,	'testing_rx'
)

-----------------------------
,(
	'funct_testing/1/rollback/2' -- check basic functionality of an execution AFTER a rollback
,	$sql_code$
select 'test'+>'success'; -- this is a dummy check really
	$sql_code$
,	$sql_check$
select ?'testing.dummy' != 'rollback'
	$sql_check$
,	''
,	'testing_rx'
)

;



--> Bookmark ft_users
INSERT INTO testing.funct_tests (id, sql_code, sql_checker, rollback_point, pg_user) VALUES
-----------------------------
(
	'users/apix_create/proper/1' -- 
,	$sql_code$
select users.apix_create(('email'+>'funct_testing@gmail.com')&('name_first'+>'alexi')&('name_last'+>'theodore'))
	$sql_code$
,	$sql_check$
select return_code(%return%) = 0;
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'users/apix_create/inproper/duplicate' -- 
,	$sql_code$
-- this is just the same code as the previous, but repeated to check for unique errors
select users.apix_create(('email'+>'funct_testing@gmail.com')&('name_first'+>'alexi')&('name_last'+>'theodore'))
	$sql_code$
,	$sql_check$
select return_code(%return%) = -1102;
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'users/apix_update/proper/name_first' -- 
,	$sql_code$
select users.apix_update((@'%users/apix_create/proper/1%'#'user_id')&('name_first'+>'bob'))
-- just updating the name_first
	$sql_code$
,	$sql_check$
select return_code(%return%) = 0;
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'users/apix_update/proper/password' -- 
,	$sql_code$
select users.apix_update((@'%users/apix_create/proper/1%'#'user_id')&('password'+>'kjabsdljabsdjlbasdjbasd'))
-- just updating the name_first
	$sql_code$
,	$sql_check$
select return_code(%return%) = 0;
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'users/apix_update/inproper/invalid_email' -- 
,	$sql_code$
select users.apix_update((@'%users/apix_create/proper/1%'#'user_id')&('email'+>'funct_testinggmail.com'))
-- trying to update the email with an invalid one, which should fail
	$sql_code$
,	$sql_check$
select return_code(%return%) = -1101;
	$sql_check$
,	''
,	'testing_rx'
)
-----------------------------
,(
	'users/apiv_details/contents' -- checking structural results 
,	$sql_code$
select users.apiv_details((@'%users/apix_create/proper/1%'#'user_id'))
	$sql_code$
,	$sql_check$
select (%return%)?&array_agg(column_name::text) from information_schema.columns where table_schema = 'users' and table_name = 'dir'
-- this is actually a pretty poor test, but a good test is difficult and requires more maintenance
-- a "good test" would check against a hard-coded return standard
	$sql_check$
,	''
,	'testing_rx'
)
;



/*
*/

;

select
	((testing.exec_funct_tests('id_pattern_off'+>'/%')->'errors')-'check SQL'**)::text as errors
into temp the_void
;


/*
-- This gives a listing of all api* functions which do not appear to have any explicit functional tests yet. --

with
	api_fs as
(
SELECT
	case_false(specific_schema||'.','global.','') ||routine_name as fnctn
FROM information_schema.routines 
WHERE
	routine_type='FUNCTION'
AND left(routine_name, 4) in ('apiv','apix')
)
,	uses as
(
select
	distinct fnctn
from testing.funct_tests, api_fs
where
	position(fnctn in sql_code) > 0
)
select
	fnctn
from api_fs
where
	fnctn not in (select * from uses)
order by fnctn
;

*/