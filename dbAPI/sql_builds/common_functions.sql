--- // --- 						--- // --- 
--- \\ ---   COMMON FUNCTIONS 	--- \\ ---
--- // --- 						--- // --- 

-- !!! THIS SCRIPT IS AN INITIALIZATION SCRIPT AND WILL BUILD FROM SCRATCH !!! --


CREATE DOMAIN DOLLAR AS numeric(10,2);
CREATE DOMAIN DOLLARS AS numeric(10,2)[];

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION empty(
	IN 	datum	ANYELEMENT
) 
RETURNS BOOLEAN AS
$$
BEGIN

CASE
	WHEN datum::text IS NULL THEN return TRUE;
	WHEN datum::text in ('', '{}', 'null', '[]') THEN return TRUE;
	ELSE return FALSE;
END CASE;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION case_false(
	IN anyelement
,	IN anyelement
,	IN anyelement
) 
RETURNS anyelement AS
$$
select case when $1 = $2 then $3 else $1 end;
$$
LANGUAGE SQL
IMMUTABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION case_true(
	IN anyelement
,	IN anyelement
,	IN anyelement
) 
RETURNS anyelement AS
$$
select case when $1 = $2 then $1 else $3 end;
$$
LANGUAGE SQL
IMMUTABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION case_switch(
	IN boolean
,	IN anyelement
,	IN anyelement
) 
RETURNS anyelement AS
$$
select case when $1 then $2 else $3 end;
$$
LANGUAGE SQL
IMMUTABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION case_empty(
	IN anyelement
,	IN anyelement
) 
RETURNS anyelement AS
$$
select case when empty($1) then $2 else $1 end;
$$
LANGUAGE SQL
IMMUTABLE
;



/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION random_alpha_numeric() 

RETURNS TEXT AS

$$
select UPPER((string_to_array('abcdefghjklmnpqrstuvwxyz23456789',NULL))[(random()*32)::int])
$$

LANGUAGE SQL
STABLE -- this must be "stable" or "volatile" in order for the function to be run uniquely for each loop w/out caching (resulting in the same answer every time)
;

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION random_letter() 

RETURNS TEXT AS

$$
select chr(floor(26 * random())::int + 65);
$$

LANGUAGE SQL
STABLE -- this must be "stable" or "volatile" in order for the function to be run uniquely for each loop w/out caching (resulting in the same answer every time)
;

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION random_digit() 

RETURNS INT AS

$$
select floor(9 * random())::int
$$

LANGUAGE SQL
STABLE -- this must be "stable" or "volatile" in order for the function to be run uniquely for each loop w/out caching (resulting in the same answer every time)
;

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION random_string_from_pattern(in pattern_string TEXT) 
RETURNS TEXT AS
$$

DECLARE

	pattern TEXT[];
	pattern_n text;
	n int := 1 ;
	string_out text;
	new_pattern TEXT[];
	probe text := '';


BEGIN

pattern := string_to_array(pattern_string, NULL);
new_pattern := pattern;

FOREACH pattern_n in ARRAY pattern LOOP
	case
		when pattern_n = '@' then 
			new_pattern[n] := random_letter();
		when pattern_n = '#' then 
			new_pattern[n] := random_digit()::text;
		when pattern_n = '%' then 
			new_pattern[n] := random_alpha_numeric()::text;
		else
	end case;

	probe := probe || n::text || pattern_n;


	n := (n + 1);

end LOOP;
	


return 
	array_to_string(new_pattern,'')
-- 	n
;

END;

$$

LANGUAGE PLPGSQL
STABLE;

COMMENT ON FUNCTION random_string_from_pattern(TEXT) is 
$$
Pattern wildcards:
-- @: random letter
-- #: random number
-- %: random letter or number
$$
;

---<<<

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION now_std() returns TIMESTAMP AS
$$
select to_char(CURRENT_TIMESTAMP,'YYYY-MM-DD HH24:MI:SS')::TIMESTAMP;
$$
LANGUAGE SQL
STABLE
;

-- COMMENT: the purpose of this function is to standardize the return of now() for only 2 digits for seconds


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION test_element_type(
	IN	value_in	TEXT
,	IN	cast_in		TEXT
) RETURNS BOOLEAN AS
$$
BEGIN
	BEGIN
	EXECUTE ('select ' || quote_literal(value_in) || '::' || cast_in);
	EXCEPTION when others THEN
		return FALSE;
	END;
RETURN TRUE;
END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
;


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
-- This function replaces all string-defined variables "%variable%" in the first argument with the value of the respective key in the second json object.

CREATE OR REPLACE FUNCTION replace_variables(
	IN	base_text		TEXT
,	IN	json_variables	JSONB
) RETURNS TEXT AS
$$
DECLARE
	each_variable RECORD;
BEGIN

FOR each_variable in (select * from jsonb_each_text(json_variables) where value IS NOT NULL)
LOOP
	base_text := replace(base_text,'%' || each_variable.key || '%', each_variable.value);
END LOOP;

-- if there are any left un-replaced, then blot them out
base_text := regexp_replace(base_text, '"%(.*?)%"', '', 'g');
base_text := regexp_replace(base_text, '%(.*?)%', '', 'g');

RETURN base_text;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
;


-- This function replaces all "%" in the first argument with the value of the text in each respective position of the second TEXT[] argument.
CREATE OR REPLACE FUNCTION replace_variables(
    IN  base_text       TEXT
,   IN  text_variables  TEXT[]
) RETURNS TEXT AS
$$
DECLARE
    each_variable TEXT;
BEGIN

FOREACH each_variable IN ARRAY text_variables LOOP
    base_text := regexp_replace(base_text, '%', each_variable);
END LOOP;

RETURN base_text;

END;
$$

LANGUAGE PLPGSQL
IMMUTABLE
;


-- Create a function that always returns the first non-NULL item
CREATE OR REPLACE FUNCTION first_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $1;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE FIRST (
        sfunc    = first_agg,
        basetype = anyelement,
        stype    = anyelement
);
 
-- Create a function that always returns the last non-NULL item
CREATE OR REPLACE FUNCTION last_agg ( anyelement, anyelement )
RETURNS anyelement LANGUAGE SQL IMMUTABLE STRICT AS $$
        SELECT $2;
$$;
 
-- And then wrap an aggregate around it
CREATE AGGREGATE LAST (
        sfunc    = last_agg,
        basetype = anyelement,
        stype    = anyelement
);




CREATE OR REPLACE FUNCTION YEAR(IN DATE) RETURNS TEXT AS $$ select to_char($1,'YYYY'); $$ LANGUAGE SQL;
CREATE OPERATOR @ (
    PROCEDURE = year
,	LEFTARG = date
)
;
COMMENT ON OPERATOR @ (DATE, NONE) IS 'Returns the YYYY part of YYYY-MM-DD date';


CREATE OR REPLACE FUNCTION MONTH(IN DATE) RETURNS TEXT AS $$ select to_char($1,'YYYY-MM'); $$ LANGUAGE SQL;
CREATE OPERATOR @@ (
    PROCEDURE = month
,	LEFTARG = date
)
;
COMMENT ON OPERATOR @@ (DATE, NONE) IS 'Returns the YYYY-MM part of YYYY-MM-DD date.';


CREATE OR REPLACE FUNCTION year_to_int(IN DATE, IN INT) RETURNS BOOLEAN AS $$ select year($1)::INT = $2; $$ LANGUAGE SQL;
DROP OPERATOR IF EXISTS @= (DATE, INT);
CREATE OPERATOR @= (
	PROCEDURE = year_to_int
,	LEFTARG = DATE
,	RIGHTARG = INT
)
;
COMMENT ON OPERATOR @= (DATE, INT) IS 'Returns TRUE if year in date of left arg equals the right arg integer.';

--->>
CREATE OR REPLACE FUNCTION money_add(IN MONEY, IN ANYELEMENT) RETURNS MONEY AS 
$$
select $1 + $2::money;
$$
LANGUAGE SQL
IMMUTABLE
;

create or replace function money_add(IN ANYELEMENT, IN MONEY) RETURNS MONEY AS 
$$
select money_add($2,$1);
$$
LANGUAGE SQL
IMMUTABLE
;

CREATE OPERATOR + (
    PROCEDURE = money_add
,   LEFTARG = MONEY
,   RIGHTARG = ANYELEMENT
,   COMMUTATOR = +

)
;
COMMENT ON OPERATOR + (MONEY, ANYELEMENT) IS 'Returns the numerical sum for $ money.';

CREATE OPERATOR + (
    PROCEDURE = money_add,
    LEFTARG = ANYELEMENT,
    RIGHTARG = MONEY
)
;
COMMENT ON OPERATOR + (ANYELEMENT, MONEY) IS 'Returns the numerical sum for $ money.';


/*
*/


CREATE or REPLACE FUNCTION 
safe_divide(
	IN numerator numeric
,	IN denomenator numeric
,	IN alternate numeric
) RETURNS numeric
AS $BODY$
DECLARE
	safe_quotient numeric;
BEGIN

IF denomenator <> 0 AND denomenator IS NOT NULL and numerator IS NOT NULL then 
	safe_quotient := numerator/denomenator;
else 
	safe_quotient := alternate;
end if;

RETURN safe_quotient;

END;

$BODY$
LANGUAGE plpgsql
IMMUTABLE;


CREATE OR REPLACE FUNCTION safe_divide(numeric, numeric) RETURNS numeric AS
$$
SELECT CASE WHEN $2 <> 0 THEN $1/$2 ELSE NULL END;
$$
LANGUAGE SQL
IMMUTABLE
;


DROP OPERATOR IF EXISTS // (numeric, numeric);
CREATE OPERATOR // (
	PROCEDURE = safe_divide
,	LEFTARG = numeric
,	RIGHTARG = numeric
)
;
COMMENT ON OPERATOR // (NUMERIC, NUMERIC) IS 'Returns NULL if fraction is NaN, otherwise returns the decimal fraction.';

DROP OPERATOR IF EXISTS # (numeric, int);
CREATE OPERATOR # (
	PROCEDURE = round
,	LEFTARG = numeric
,	RIGHTARG = int
)
;
COMMENT ON OPERATOR # (NUMERIC, INT) IS 'Returns the left float rounded to the number of decimals specified by the right.';


CREATE OR REPLACE FUNCTION safe_textcat(text, text) RETURNS text AS
$$
SELECT COALESCE($1,'') || COALESCE($2,'');
$$
LANGUAGE SQL
IMMUTABLE
;

DROP OPERATOR IF EXISTS + (text,text);
CREATE OPERATOR + (
	PROCEDURE = safe_textcat
,	LEFTARG = text
,	RIGHTARG = text
)
;
COMMENT ON OPERATOR + (TEXT, TEXT) IS 'Returns the right text concatenated to the left, where NULL is intepreted as blank for both sides.';


CREATE OR REPLACE FUNCTION nullsafe(TEXT) RETURNS TEXT AS
$$
select (case when $1 is NULL then ''::TEXT else $1 end);
$$
LANGUAGE SQL
IMMUTABLE
;


CREATE OR REPLACE FUNCTION date_diff (units TEXT, start_t TIMESTAMP, end_t TIMESTAMP) 
     RETURNS INT AS $$
   DECLARE
     diff_interval INTERVAL;
     diff INT = 0;
     years_diff INT = 0;
   BEGIN
     IF units IN ('yy', 'yyyy', 'year', 'mm', 'm', 'month') THEN
       years_diff = DATE_PART('year', end_t) - DATE_PART('year', start_t);
 
       IF units IN ('yy', 'yyyy', 'year') THEN
         -- SQL Server does not count full years passed (only difference between year parts)
         RETURN years_diff;
       ELSE
         -- If end month is less than start month it will subtracted
         RETURN years_diff * 12 + (DATE_PART('month', end_t) - DATE_PART('month', start_t)); 
       END IF;
     END IF;
 
     -- Minus operator returns interval 'DDD days HH:MI:SS'  
     diff_interval = end_t - start_t;
 
     diff = diff + DATE_PART('day', diff_interval);
 
     IF units IN ('wk', 'ww', 'week') THEN
       diff = diff/7;
       RETURN diff;
     END IF;
 
     IF units IN ('dd', 'd', 'day') THEN
       RETURN diff;
     END IF;
 
     diff = diff * 24 + DATE_PART('hour', diff_interval); 
 
     IF units IN ('hh', 'hour') THEN
        RETURN diff;
     END IF;
 
     diff = diff * 60 + DATE_PART('minute', diff_interval);
 
     IF units IN ('mi', 'n', 'minute') THEN
        RETURN diff;
     END IF;
 
     diff = diff * 60 + DATE_PART('second', diff_interval);
 
     RETURN diff;
   END;
   $$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION space_join(IN TEXT, IN TEXT, OUT TEXT) AS
$$
SELECT COALESCE($1 || ' ' || $2, $1, $2);
$$

LANGUAGE SQL
IMMUTABLE
;


DROP OPERATOR IF EXISTS & (text, text);
CREATE OPERATOR & (
    PROCEDURE = space_join,
    LEFTARG = text,
    RIGHTARG = text
)
;
COMMENT ON OPERATOR & (TEXT, TEXT) IS 'Returns the right text concatenated to the left with a space between. If either is NULL, then no spaces are added.';


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION case_switch_operator(
	IN 	BOOLEAN
,	IN 	TEXT[]
,	OUT TEXT
) AS
$$
select case when $1 then $2[1] ELSE $2[2] END;
$$
LANGUAGE SQL
IMMUTABLE
;

DROP OPERATOR IF EXISTS ? (BOOLEAN, TEXT[]);
CREATE OPERATOR ? (
    PROCEDURE = case_switch_operator,
    LEFTARG = BOOLEAN,
    RIGHTARG = TEXT[]
)
;
COMMENT ON OPERATOR ? (BOOLEAN, TEXT[]) IS 'If left arg is TRUE/FALSE then return first/second position of right arg.';


/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION fit(IN string TEXT, IN max_length INT) RETURNS TEXT AS
$$
DECLARE
BEGIN

IF length(string) > max_length THEN
	return left(string,max_length/2-1) || '...' || right(string,max_length/2-2);
ELSE
	return string;
END IF;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION strict(
	IN 	BOOLEAN
,	OUT BOOLEAN
) AS
$$
select 
    CASE 
        WHEN $1 THEN TRUE
        ELSE FALSE 
    END;
$$
LANGUAGE SQL
IMMUTABLE
;

DROP OPERATOR IF EXISTS ?? (boolean,NONE);
CREATE OPERATOR ?? (
    PROCEDURE = strict,
    LEFTARG = boolean
)
;
COMMENT ON OPERATOR ?? (BOOLEAN, NONE) IS 'Return TRUE only if left arg is TRUE, otherwise FALSE (no NULLs).';

/*
_|_|_|_|
_|
_|_|_|
_|
_|
*/
CREATE OR REPLACE FUNCTION limited_float(IN numeric) RETURNS numeric AS
$$
select case when $1::int = $1 then $1::int else $1#2 end
$$
LANGUAGE SQL
IMMUTABLE
;


CREATE OR REPLACE FUNCTION full_agg_array_statef
(
	IN array_in_agg anyarray
,	IN array_in anyarray
,	OUT array_out anyarray
) AS $$
BEGIN

array_out := array_in_agg || array_in;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE;


DROP AGGREGATE IF EXISTS full_agg_array (anyarray);
CREATE AGGREGATE full_agg_array(anyarray) 
(
    SFUNC = full_agg_array_statef,
    STYPE = anyarray
)
;


CREATE OR REPLACE FUNCTION strip_duplicates(IN array_in ANYARRAY, OUT array_out anyarray) AS
$$
DECLARE
BEGIN

select
    array_agg(DISTINCT arrys)
into array_out
from (select arrys from unnest(array_in) arrys) arys
;

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;



CREATE OR REPLACE FUNCTION distinct_count(IN array_in anyarray, OUT array_out TEXT) AS
$$
DECLARE
BEGIN

with
	poo as
(
select 
	unnest
,	count(*)
from unnest(array_in) 
group by unnest
)
select
	string_agg(unnest::text || ' (x' || count ||')', chr(10))
into array_out
from poo
;


END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

/*
*/
CREATE OR REPLACE FUNCTION text_contained_in_array(IN left_in TEXT, IN right_in TEXT[])
RETURNS BOOLEAN AS
$$
BEGIN
    RETURN (SELECT array[left_in] <@ right_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;


DROP OPERATOR IF EXISTS <@ (TEXT, TEXT[]);
CREATE OPERATOR <@ (
    PROCEDURE = text_contained_in_array
,   LEFTARG = TEXT
,   RIGHTARG = TEXT[]
)
;
COMMENT ON OPERATOR <@ (TEXT, TEXT[]) IS 'Returns TRUE if the left string is contained by the right array.';


CREATE OR REPLACE FUNCTION text_contained_in_array(IN left_in TEXT[], IN right_in TEXT)
RETURNS BOOLEAN AS
$$
BEGIN
    RETURN (SELECT array[right_in] <@ left_in);
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;


DROP OPERATOR IF EXISTS @> (TEXT, TEXT[]);
CREATE OPERATOR @> (
    PROCEDURE = text_contained_in_array
,   LEFTARG = TEXT[]
,   RIGHTARG = TEXT
)
;
COMMENT ON OPERATOR @> (TEXT[], TEXT) IS 'Returns TRUE if the left array contains the right string.';


--->>
CREATE OR REPLACE FUNCTION INT_contained_in_array(IN left_in INT[], IN right_in INT)
RETURNS BOOLEAN AS
$$
BEGIN

RETURN (SELECT left_in @> array[right_in]);

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

-- DROP OPERATOR IF EXISTS <@ (INT, INT[]);
CREATE OPERATOR @> (
    PROCEDURE = INT_contained_in_array,
    LEFTARG = INT[],
    RIGHTARG = INT
)
;
COMMENT ON OPERATOR @> (INT[], INT) IS 'Returns TRUE if the left INT is contained by the right array.';

--->>
CREATE OR REPLACE FUNCTION INT_contained_in_array(IN left_in INT, IN right_in INT[])
RETURNS BOOLEAN AS
$$
BEGIN

RETURN (SELECT array[left_in] <@ right_in);

END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

-- DROP OPERATOR IF EXISTS <@ (INT, INT[]);
CREATE OPERATOR <@ (
    PROCEDURE = INT_contained_in_array,
    LEFTARG = INT,
    RIGHTARG = INT[]
)
;
COMMENT ON OPERATOR <@ (INT, INT[]) IS 'Returns TRUE if the right INT is contained by the left array.';



--->>
CREATE OR REPLACE FUNCTION array_sum(
	IN 	NUMERIC[]
) RETURNS NUMERIC AS
$$
SELECT SUM(unnest) FROM unnest($1);
$$
LANGUAGE SQL
IMMUTABLE
;


CREATE OR REPLACE FUNCTION min(IN ANYARRAY) RETURNS ANYELEMENT AS
$$
select min(unnest) from unnest($1);
$$
LANGUAGE SQL
IMMUTABLE
;

CREATE OR REPLACE FUNCTION max(IN ANYARRAY) RETURNS ANYELEMENT AS
$$
select max(unnest) from unnest($1);
$$
LANGUAGE SQL
IMMUTABLE
;


--->>
CREATE OR REPLACE FUNCTION email_validate(TEXT) RETURNS BOOLEAN AS
$$
BEGIN
RETURN $1~ '.+\@.+\..+';
END;
$$
LANGUAGE PLPGSQL
IMMUTABLE
;

CREATE DOMAIN EMAIL AS CITEXT CHECK(email_validate(VALUE));


--->>
CREATE OR REPLACE FUNCTION bool_and(IN BOOLEAN, IN BOOLEAN) RETURNS BOOLEAN AS 
$$
select
    CASE
        WHEN $1 IS TRUE AND $2 IS TRUE THEN TRUE
        ELSE FALSE
    END;
$$ 
LANGUAGE SQL
;

DROP OPERATOR IF EXISTS & (BOOLEAN, BOOLEAN);
CREATE OPERATOR & (
    PROCEDURE = bool_and
,   LEFTARG = BOOLEAN
,   RIGHTARG = BOOLEAN
)
;
COMMENT ON OPERATOR & (BOOLEAN, BOOLEAN) IS 'Returns TRUE if both left and right params are TRUE, otherwise FALSE.';


--->>
CREATE OR REPLACE FUNCTION "not"(IN BOOLEAN) RETURNS BOOLEAN AS 
$$
	select NOT $1;
$$
LANGUAGE SQL;

CREATE OPERATOR ! (
    PROCEDURE = not
,   RIGHTARG = BOOLEAN
)
;
COMMENT ON OPERATOR ! (NONE, BOOLEAN) IS 'Returns the opposite ("not") of the left arg.';


--->>
CREATE OR REPLACE FUNCTION safe_add(IN ANYELEMENT, IN ANYELEMENT) RETURNS ANYELEMENT AS 
$$
	select COALESCE($1+$2,0); 
$$
LANGUAGE SQL;

CREATE OPERATOR & (
    PROCEDURE = safe_add
,   LEFTARG = ANYELEMENT
,   RIGHTARG = ANYELEMENT
)
;
COMMENT ON OPERATOR & (ANYELEMENT, ANYELEMENT) IS 'Returns the some of the left and right args and if either is NULL, then returns 0.';


/*
*/

create view custom_operators as

with
    ops as
(
SELECT 
    oid
,   *
FROM pg_operator
WHERE
	oprowner = (select usesysid from pg_user where usename = 'the_architect')
)
,   pgta as
(
select
    oid as oprresult
,   typname
from pg_type
)
,   pgtr as
(
select
    oid as oprright
,   typname as right_type
from pg_type
)
,   pgtl as
(
select
    oid as oprleft
,   typname as left_type
from pg_type
)

select
    oprname as operator
,   left_type
,   right_type
,   typname as return_type
,   COALESCE('('||left_type||')','') & oprname & COALESCE('('||right_type||')','') & '-->' & typname as formula
,   obj_description(ops.oid) as description
,   oprcode as operator_function
-- ,	*
from ops
left join pgtr using (oprright)
left join pgtl using (oprleft)
join pgta using (oprresult)
order by left_type, right_type, return_type
;


CREATE OR REPLACE FUNCTION date_diff (
    units VARCHAR(30)
,   start_t TIMESTAMP
,   end_t TIMESTAMP
) RETURNS INT AS $$
DECLARE
    diff_interval INTERVAL; 
    diff INT = 0;
    years_diff INT = 0;
BEGIN
IF units IN ('yy', 'yyyy', 'year', 'mm', 'm', 'month') THEN
    years_diff = DATE_PART('year', end_t) - DATE_PART('year', start_t);

    IF units IN ('yy', 'yyyy', 'year') THEN
        -- SQL Server does not count full years passed (only difference between year parts)
        RETURN years_diff;
    ELSE
        -- If end month is less than start month it will subtracted
        RETURN years_diff * 12 + (DATE_PART('month', end_t) - DATE_PART('month', start_t)); 
    END IF;
END IF;

-- Minus operator returns interval 'DDD days HH:MI:SS'  
diff_interval = end_t - start_t;

diff = diff + DATE_PART('day', diff_interval);

IF units IN ('wk', 'ww', 'week') THEN
    diff = diff/7;
    RETURN diff;
END IF;

IF units IN ('dd', 'd', 'day') THEN
    RETURN diff;
END IF;

diff = diff * 24 + DATE_PART('hour', diff_interval); 

IF units IN ('hh', 'hour') THEN
    RETURN diff;
END IF;

diff = diff * 60 + DATE_PART('minute', diff_interval);

IF units IN ('mi', 'n', 'minute') THEN
    RETURN diff;
END IF;

diff = diff * 60 + DATE_PART('second', diff_interval);

RETURN diff;
END;
$$
LANGUAGE plpgsql
IMMUTABLE
;

CREATE OR REPLACE VIEW custom_functions as

with
    base as
(
select
    proname
,   proargtypes
,   typname as outputs
,   obj_description(pg_proc.oid) as comment
from pg_proc
join pg_type on pg_type.oid = pg_proc.prorettype
WHERE
    proowner = (select usesysid from pg_user where usename = 'the_architect')
)
,   args_pre as
(
select
    proname
,   unnest(proargtypes) as oid
from base
)
,   args as
(
select
    proname
,   string_agg(typname, ', ') as inputs
from args_pre
join pg_type on pg_type.oid = args_pre.oid
group by proname
)
,   report as
(
select
    proname as name
,   inputs
,   outputs
,   comment
from base
join args using (proname)
)

select
--  proname||'('||args||')'||' --> '||rtns
    *
from report
;


CREATE OR REPLACE VIEW json_extensions as

select
    *
from custom_functions
where
    ('{'||inputs||'}')::text[] && '{jsonb,json}'
OR  outputs in ('json','jsonb')
;