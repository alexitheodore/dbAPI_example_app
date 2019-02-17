-- ROLLBACK; BEGIN;

--- // --- 			--- // --- 
--- \\ ---  USERS	--- \\ ---
--- // --- 			--- // --- 

-- !!! THIS SCRIPT IS AN INITIALIZATION SCRIPT AND WILL BUILD FROM SCRATCH !!! --

DROP SCHEMA IF EXISTS users CASCADE;
CREATE SCHEMA users;
SET search_path TO "global";


/*

 ----------------
	||		||		
	||		||		
	||		||		

TABLE: dir

*/


CREATE TABLE users.dir
(
	user_id			SERIAL		
		PRIMARY KEY
,	email 			EMAIL		
		UNIQUE
		NOT NULL
,	user_date		TIMESTAMP	
		DEFAULT now_std()
,	name_first		TEXT
,	name_last		TEXT
,	class			TEXT
		NOT NULL 
		DEFAULT ((?'users.classes')::text[])[1]
		CHECK (class <@ (?'users.classes')::text[])
,	active			BOOLEAN		
		NOT NULL
		DEFAULT FALSE
,	password		TEXT
,	dashboard		JSONB		
		CHECK (dashboard ?&! ((?'users.classes')::text[]))
)
;


CREATE TRIGGER trigger_snapshot
AFTER UPDATE ON users.dir
FOR EACH ROW
WHEN ((?'dbAPI.snapshots')::BOOLEAN AND old.* IS DISTINCT FROM new.*)
EXECUTE PROCEDURE snapshot_take()
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION users.apiv_dir(
	IN	json_in		JSONB
,	OUT	json_out	JSONB
) 
AS $$
DECLARE
	sql_exec TEXT;
BEGIN

-- validation/cleansing
CASE 
	WHEN json_in?'sort_dir' AND NOT UPPER(json_in->>'sort_dir') <@ '{ASC, DESC}' 
		THEN json_out := return_code(-1002) & ('return_msg'+>'Invalid sort_dir'); RETURN;
	WHEN json_in?'sort_name' AND NOT json_in->>'sort_name' <@ '{email, name_first, name_last, active}' 
		THEN json_out := return_code(-1002) & ('return_msg'+>'Invalid sort_name'); RETURN;
	WHEN json_in?'class' AND NOT json_in->>'class' <@ '{admin, client}' 
		THEN json_out := return_code(-1002) & ('return_msg'+>'Invalid class'); RETURN;
	WHEN json_in?'active' AND NOT UPPER(json_in->>'active') <@ '{TRUE, FALSE}' 
		THEN json_out := return_code(-1002) & ('return_msg'+>'Invalid active state'); RETURN;
	ELSE
END CASE;

-- defaults
json_in := @'{"limit":100, "offset":0, "sort_name":"user_id", "sort_dir":"DESC", "active":"TRUE"}' & json_in;

-- base query
sql_exec :=
$sql$
with
	base as
(
select
	user_id
,	email
,	name_first
,	name_last
,	active
from users.dir
WHERE
	CASE 
		WHEN '%class%' <> '' THEN class = '%class%' 
		WHEN '%active%' <> '' THEN active = '%active%'::BOOLEAN 
		ELSE TRUE
	END

ORDER BY %sort_name% %sort_dir%

LIMIT %limit%
OFFSET %offset%

)
select
	jsonb_agg(row_to_json(base))
FROM base
;
$sql$
;


-- fill in the blanks
sql_exec := replace_variables(sql_exec, json_in);


-- debuging --
IF json_in ? 'debug' THEN
	json_out := json_in & ('sql_exec'+>sql_exec); return;
END IF;


-- run the query
IF 
	sql_exec <> '' THEN
		EXECUTE sql_exec into json_out;
	ELSE
		json_out := return_code(-1002) & ('sql_exec'+>sql_exec);
		RETURN;
END IF;

-- for compliance and consistancy
IF json_out IS NULL
	THEN json_out := '[]';
END IF;

RETURN;

END
$$

LANGUAGE PLPGSQL
VOLATILE
;



/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION users.apiv_details(
	IN	json_in		JSONB
,	OUT	json_out	JSONB
) 
AS $$
DECLARE
	user_id_in INT := json_in->#'user_id';
BEGIN

-- validation --
IF	NOT json_in?|'{user_id, email}' 
THEN
	json_out := json_out & return_code(-1103);
	RETURN;
END IF;

select
	row_to_json(dir.*)
	into json_out
from users.dir
where
	CASE
		WHEN json_in?'user_id' THEN user_id = json_in->#'user_id'
		WHEN json_in?'email' THEN email = json_in->>'email'
		ELSE FALSE
	END
;

IF json_out is NULL THEN 
	json_out := json_out & return_code(-1000);
	return; 
END IF;

END;
$$

LANGUAGE PLPGSQL
STABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION users.apix_create(
	IN	json_in				JSONB
,	OUT json_out			JSONB
) AS
$$
DECLARE
	return_code 	INT;
BEGIN

-- validation
CASE
	WHEN NOT json_in?&'{email, name_last, name_first}' 
		THEN json_out := return_code(-1100); RETURN;
	ELSE
END CASE;

BEGIN
	-- cleanse json_in of all parameters except those accepted
	json_in := json_in#&'{email, name_last, name_first, password, debug}';

	json_out := jsonb_table_insert('users','dir', json_in, json_in#'debug');
EXCEPTION 
	WHEN check_violation 
		THEN json_out := return_code(-1101); RETURN;
	WHEN unique_violation
		THEN json_out := return_code(-1102); RETURN;
	WHEN not_null_violation
		THEN json_out := return_code(-1101); RETURN;
END;

json_out := 
	json_out
&	users.apiv_details(json_out)
&	return_code(0)
;

END;
$$

LANGUAGE PLPGSQL
VOLATILE
;



/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION users.apix_update(
	IN	json_in				JSONB
,	OUT json_out			JSONB
) AS
$$
DECLARE
	return_code 	INT;
	error_stuff		TEXT;
BEGIN

-- validation

CASE
	WHEN NOT json_in?&'{user_id}' 
		THEN json_out := return_code(-1103); RETURN;
	ELSE
END CASE;

IF json_in?'password'
	-- IF a password is supplied, then activate user
	THEN json_in:=json_in & ('active'+>TRUE);
END IF;

	BEGIN
		json_out := jsonb_table_update('users','dir', json_in#&'{user_id}', json_in, json_in#'debug');
	EXCEPTION 
		WHEN check_violation THEN
			GET STACKED DIAGNOSTICS error_stuff = CONSTRAINT_NAME;
			json_out := return_code(CASE 
				WHEN error_stuff = 'dir_dashboard_check' THEN -1104
				WHEN error_stuff = 'dir_class_check' THEN -1104
				WHEN error_stuff = 'email_check' THEN -1101
			END); RETURN;
		WHEN unique_violation
			THEN json_out := return_code(-1102); RETURN;
	END;

IF json_in->?'debug' THEN 
	RETURN;
END IF;

json_out := 
	users.apiv_details(json_in)
&	return_code(0)
;

END;
$$

LANGUAGE PLPGSQL
VOLATILE
;