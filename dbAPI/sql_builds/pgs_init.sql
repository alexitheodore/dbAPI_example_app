-- !!! MUST BE ONLY RUN ONCE !!! --

CREATE USER the_architect WITH SUPERUSER CREATEROLE CREATEDB PASSWORD '{pass_the_architect}';
CREATE USER admin_rwx WITH PASSWORD '{pass_admin_rwx}';
CREATE USER prod_rx WITH PASSWORD '{pass_prod_rx}';
CREATE ROLE testing_rx INHERIT;
CREATE ROLE testing_rwx INHERIT;
