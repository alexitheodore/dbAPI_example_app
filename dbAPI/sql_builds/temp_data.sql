DO

$$
DECLARE
  loop_n int :=0;
BEGIN

IF current_setting('dbAPI.environment') != 'dev' THEN return;
ELSE END IF;

perform users.apix_create(('email'+>'1@gmail.com')&('name_first'+>'alexi')&('name_last'+>'theodore'));
perform users.apix_create(('email'+>'2@gmail.com')&('name_first'+>'alexi')&('name_last'+>'theodore'));
perform users.apix_create(('email'+>'3@gmail.com')&('name_first'+>'alexi')&('name_last'+>'theodore'));

END;
$$
LANGUAGE PLPGSQL
;

