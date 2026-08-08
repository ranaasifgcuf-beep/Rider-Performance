-- ============================================================
-- Step 3 of data migration: re-enable all FK constraints after
-- data has been loaded, and VALIDATE them (checks the loaded
-- data actually satisfies referential integrity -- if this
-- fails, it tells you exactly which row/table is orphaned).
--
-- Run this in the NEW instance's SQL Worksheet, Script mode,
-- AFTER all tables you intend to load are loaded.
-- ============================================================
BEGIN
  FOR c IN (
    SELECT table_name, constraint_name
    FROM user_constraints
    WHERE constraint_type = 'R'
      AND status = 'DISABLED'
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE
        'ALTER TABLE "' || c.table_name || '" ENABLE VALIDATE CONSTRAINT "' || c.constraint_name || '"';
    EXCEPTION
      WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAILED to enable ' || c.constraint_name ||
                              ' on ' || c.table_name || ': ' || SQLERRM);
    END;
  END LOOP;
END;
/

-- If anything printed "FAILED to enable ..." above, that table has rows
-- referencing a parent row that doesn't exist yet in the new DB -- usually
-- means a lookup/master/parent table still needs loading. Load it, then
-- re-run this script (already-enabled constraints are skipped automatically
-- since the query only picks up ones still DISABLED).
