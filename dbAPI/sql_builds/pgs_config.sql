-- THIS SCRIPT MUST BE RUN WITH connection string: //the_architect@localhost:5433/${vars[database]}

DROP SCHEMA IF EXISTS public CASCADE;

DROP SCHEMA IF EXISTS "global" CASCADE;
CREATE SCHEMA "global";

SET search_path TO "global";

ALTER DATABASE {database} SET search_path TO "global";
ALTER SCHEMA "global" OWNER TO the_architect;

-- CREATE EXTENSION IF NOT EXISTS plpythonu;

-- CREATE EXTENSION IF NOT EXISTS dblink;

-- CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE EXTENSION IF NOT EXISTS ltree;