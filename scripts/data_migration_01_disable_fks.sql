-- ============================================================
-- Step 1 of data migration: disable all FK constraints in the
-- NEW database so tables can be loaded in ANY order (no need to
-- work out parent/child dependency order by hand).
--
-- Run this in the NEW instance's SQL Worksheet, Script mode.
-- Safe to re-run (constraints already disabled are skipped).
-- ============================================================
BEGIN
  FOR c IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE constraint_type = 'R'   -- R = referential (foreign key)
      AND status = 'ENABLED'
  ) LOOP
    EXECUTE IMMEDIATE
      'ALTER TABLE "' || c.table_name || '" DISABLE CONSTRAINT "' || c.constraint_name || '"';
  END LOOP;
END;
/
