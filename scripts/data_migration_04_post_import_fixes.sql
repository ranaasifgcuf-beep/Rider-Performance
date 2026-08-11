-- ============================================================
-- Run AFTER data_migration_00_alter_pk_on_populated_tables.sql,
-- and after connecting as ADMIN for the GRANT (switch login for
-- that one line, then back to your schema user for the rest).
-- ============================================================

-- 1) Run as ADMIN:
-- GRANT EXECUTE ON DBMS_CRYPTO TO <your_schema_name>;

-- 2) Run as your schema user: fix the hardcoded schema qualifier
create or replace function apex_auth_fn(
  p_username in varchar2,
  p_password in varchar2
) return boolean
is
begin
  return sec_auth_pkg.authenticate(p_username, p_password);
end;
/
