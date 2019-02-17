-- !!! THIS SCRIPT IS AN INITIALIZATION SCRIPT AND WILL BUILD FROM SCRATCH !!! --

-- ALL IN THIS FILE INTENDED FOR THE GLOBAL SCHEMA --

/*
------------------
	||		||		
	||		||		
	||		||		
*/
DROP TABLE IF EXISTS return_codes;
CREATE TABLE return_codes
(
	return_code		numeric		PRIMARY KEY
,	desc_detail		text
,	desc_support	text
,	desc_customer	text
)
;

COMMENT ON TABLE return_codes is 
$$
-- positive codes are sucesses
-- negative codes are errors

VERSIONS:

	~1~
	- 


$$
;


/*
----------
	||	 
	||	 
	||	 
*/
DROP TABLE IF EXISTS settings;
CREATE TABLE settings 
(
	setting_name	TEXT	PRIMARY KEY
,	value			TEXT
,	value_type		REGTYPE
,	description		TEXT
)
;

COMMENT ON TABLE settings is 
$$
-- settings table is used for single-dimension key-value pairs, organized by category
-- setting_name should be in directory form, e.g.: main_category/sub_category/name
$$
;


/*
----------
	||	 
	||	 
	||	 
*/
DROP TABLE IF EXISTS options;
CREATE TABLE options 
(
	option_name	TEXT
,	properties	JSON
)
;

COMMENT ON TABLE settings is 
$$
-- options table is used for multi-dimension key-value pairs under the title of a single option_id
-- options_name should be in directory form, e.g.: main_category/sub_category/name
$$
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION apiv_settings() RETURNS JSONB AS
$$
BEGIN

RETURN
(
SELECT
	json_agg
	(
	setting_name
	+>
	CASE
		WHEN value_type::text = 'text[]' THEN array_to_json(value::text[])
		WHEN value_type::text = 'int[]' THEN array_to_json(value::int[])
		WHEN value_type::text = 'json' THEN value::json
		WHEN value_type::text = 'jsonb' THEN value::json
		WHEN value_type::text = 'int' THEN to_json(value::int)
	ELSE
		to_json(value)
	END
	)::json
FROM settings
);

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
CREATE OR REPLACE FUNCTION setting_lookup(
	IN	settings_name_in	TEXT
) RETURNS TEXT AS
$$
SELECT value from settings where setting_name = settings_name_in;
$$

LANGUAGE SQL
IMMUTABLE
;

CREATE OPERATOR ?(
    PROCEDURE = setting_lookup
,	RIGHTARG = TEXT
)
;
COMMENT ON OPERATOR ? (NONE, TEXT) IS 'Returns the textual value of the setting_name given in the right arg.';



/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION setting_update(
	IN	settings_name_in	TEXT
,	IN 	value_in			TEXT
) RETURNS TEXT AS
$$
UPDATE settings SET
	value = value_in
where 
	setting_name = settings_name_in
returning value
;
$$

LANGUAGE SQL
VOLATILE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION options_lookup(
	IN	option_name_in	TEXT
) RETURNS JSON AS
$$
SELECT properties from options where option_name = option_name_in;
$$
LANGUAGE SQL
STABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION apiv_return_codes(
	OUT json_out 	JSONB
) AS
$$
BEGIN
select 
	json_agg(row_to_json(return_codes)) into json_out 
from return_codes
;
END;
$$
LANGUAGE PLPGSQL
STABLE
;