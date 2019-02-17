--> Bookmark return_codes
DELETE FROM return_codes;
INSERT INTO return_codes 
(return_code, desc_detail)
VALUES
-- GLOBAL
(-1000,	'General Uncaught API Function SQL error'),
(00001,	'Generic, run-of-the-mill success'),
(-1002, 'you have supplied some bad or unaccepted parameters'),
(-1003, 'your API request contains invalid JSON'),
(-1004, 'you requested an undefined endpoint'),
(-1007, 'Sorry, you do not have permission for that.'),

-- Users
(01100,	'Users'),
(-1100,	'Must supply email, first name and last name.'),
(-1101,	'Invalid email address.'),
(-1102,	'That user already exists.'),
(-1103,	'Must supply a user_id.'),
(-1104,	'Invalid user class.'),

(00000,	'anonymous')
;


--> Bookmark settings
DELETE FROM SETTINGS;
INSERT INTO SETTINGS VALUES
--(setting_name, value, value_type, description)
	('users.classes', '{client,admin}', 'text[]', '')

,	('dbAPI.snapshots', 'TRUE', 'boolean', 'Determines whether update snapshots are enabled.')
,	('dbAPI.environments', '{live,dev}', 'text[]', 'List of named development environments.')
,	('dbAPI.environment', current_setting('dbAPI.environment'), 'text', 'The current environment type.')

,	('testing.dummy', '', 'text', '')

;
