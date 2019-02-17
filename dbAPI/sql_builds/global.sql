--- // --- 			--- // --- 
--- \\ ---  GLOBAL	--- \\ ---
--- // --- 			--- // --- 

-- !!! THIS SCRIPT IS AN INITIALIZATION SCRIPT AND WILL BUILD FROM SCRATCH !!! --
-- * because the schema is global, it is destroyed and created in an earlier build file 
-- versioning
/*

Version 0.1
	- 

*/

-- DROP TABLE snapshots;
CREATE TABLE snapshots
(
	snapshot_id		SERIAL	PRIMARY KEY
,	txn_id			BIGINT
,	txn_date		TIMESTAMP
,	txn_table		TEXT
,	txn_snapshot	JSONB
,	txn_delta		JSONB
-- ,	notes			TEXT[]
--		⤷ each note entry is an array of three parts: [date, user, notes]
)
;


CREATE OR REPLACE FUNCTION snapshot_take() RETURNS TRIGGER AS
$$
BEGIN

INSERT INTO snapshots (txn_id, txn_date, txn_table, txn_snapshot, txn_delta)
VALUES
( 
	txid_current()
,	now()
,	TG_TABLE_SCHEMA+'.'+TG_TABLE_NAME
,	row_to_json(NEW)::jsonb-&'{exif}'
,	jsonb_delta(row_to_json(NEW)::JSONB,row_to_json(OLD)::JSONB)
)
;

RETURN NULL;
END;
$$
LANGUAGE PLPGSQL
VOLATILE
;


-------------------



CREATE OR REPLACE FUNCTION snapshot_restore(
	IN	txn_id_in	BIGINT
,	OUT json_out	JSONB
) AS
$$
DECLARE
	snapshot	RECORD;
	sql_exec	TEXT;
BEGIN

-- disable snapshots temporarily? no, because then you cannot undo the undo...
-- SET SESSION dbAPI.snapshot = FALSE;

FOR snapshot IN (SELECT * FROM snapshots WHERE txn_id = txn_id_in order by snapshot_id desc) LOOP

	-- get the changed values list
	select
		string_agg('	'||key||' = '||quote_literal(value), chr(10)+',')
	into sql_exec
	from jsonb_each_casted(snapshot.txn_snapshot)
	;

	-- get the primary key name for the given table
	SELECT
		'table_pk_name'+>attname
	into json_out
	FROM   pg_index i
	JOIN   pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
	WHERE  i.indrelid = (snapshot.txn_table)::regclass
	AND    i.indisprimary
	;

	-- set parameters
	json_out := json_out & ('table_name'+>snapshot.txn_table) & ('table_pk_id'+>(snapshot.txn_snapshot->>(json_out->>'table_pk_name')));

	-- build the sql script
	sql_exec :=
	$sql$
	UPDATE %table_name% SET
	$sql$||sql_exec||$sql$
	WHERE
		%table_pk_name% = %table_pk_id%
	$sql$
	;
	sql_exec := replace_variables(sql_exec, json_out);

	-- do the snapshot rollback
	EXECUTE sql_exec;

	-- output diagnostics/reporting
	json_out := json_out & ('sql_exec'+>sql_exec);

END LOOP;

json_out := json_out & return_code(1);

END;
$$
LANGUAGE PLPGSQL
VOLATILE
;


CREATE OR REPLACE FUNCTION domain_env(
	OUT domain_env TEXT
) AS
$$
BEGIN

BEGIN
	domain_env := current_setting('dbAPI.domain_env');
EXCEPTION when others 
THEN END;

IF NOT (domain_env <@ (?'dbAPI.environments')::text[]) 
	THEN domain_env := 'dev';
END IF;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;



/*
*/
-- this version of the function just extracts the numerical return_code
CREATE OR REPLACE FUNCTION return_code(IN json_in JSONB) RETURNS INT AS
$$
DECLARE
BEGIN
    return (json_in->>'return_code')::INT;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

-- this version of the function builds the json object for a return-code
CREATE OR REPLACE FUNCTION return_code(IN rc INT) RETURNS JSONB AS
$$
DECLARE
BEGIN
    return 'return_code' +> rc;
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;


-- This version of the function collects a text message payload and issues an error email.
-- It is intended to be used for non-trivial return_codes that need to be actively monitored.
CREATE OR REPLACE FUNCTION return_code(IN rc INT, IN message_payload JSONB) RETURNS JSONB AS
$$
BEGIN
    return 'return_code' +> rc;
END;
$$
LANGUAGE PLPGSQL
VOLATILE
;
