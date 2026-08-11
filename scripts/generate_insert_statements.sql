-- ============================================================
-- Generates ready-to-run INSERT statements for the master/
-- reference/security tables, without relying on any "download
-- as Insert" UI feature (which isn't available on this instance).
--
-- Run on the OLD database, in SQL Worksheet, SCRIPT MODE (the
-- "Run Script" button, not the regular single-statement Run) --
-- same mode you used earlier for the DDL export. Output appears
-- in the "Script Output" tab below as plain text; use its
-- download/save icon to save it as one .sql file, then run that
-- file against the NEW database's SQL Worksheet.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 32767
SET PAGESIZE 0
SET FEEDBACK OFF

DECLARE
  l_cur    PLS_INTEGER;
  l_desc   DBMS_SQL.DESC_TAB;
  l_cnt    PLS_INTEGER;
  l_status PLS_INTEGER;
  l_val_v  VARCHAR2(4000);
  l_val_n  NUMBER;
  l_val_d  DATE;
  l_val_ts TIMESTAMP;
  l_line   VARCHAR2(32000);

  PROCEDURE dump_table(p_table IN VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('-- ===== ' || p_table || ' =====');
    l_cur := DBMS_SQL.OPEN_CURSOR;
    DBMS_SQL.PARSE(l_cur, 'SELECT * FROM "' || p_table || '"', DBMS_SQL.NATIVE);
    DBMS_SQL.DESCRIBE_COLUMNS(l_cur, l_cnt, l_desc);

    FOR i IN 1 .. l_cnt LOOP
      CASE l_desc(i).col_type
        WHEN 2   THEN DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_n);
        WHEN 12  THEN DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_d);
        WHEN 180 THEN DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_ts);
        WHEN 181 THEN DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_ts);
        WHEN 231 THEN DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_ts);
        ELSE           DBMS_SQL.DEFINE_COLUMN(l_cur, i, l_val_v, 4000);
      END CASE;
    END LOOP;

    l_status := DBMS_SQL.EXECUTE(l_cur);

    WHILE DBMS_SQL.FETCH_ROWS(l_cur) > 0 LOOP
      l_line := 'INSERT INTO "' || p_table || '" (';
      FOR i IN 1 .. l_cnt LOOP
        l_line := l_line || '"' || l_desc(i).col_name || '"' || CASE WHEN i < l_cnt THEN ',' ELSE '' END;
      END LOOP;
      l_line := l_line || ') VALUES (';
      FOR i IN 1 .. l_cnt LOOP
        CASE l_desc(i).col_type
          WHEN 2 THEN
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_n);
            l_line := l_line || NVL(TO_CHAR(l_val_n), 'NULL');
          WHEN 12 THEN
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_d);
            IF l_val_d IS NULL THEN
              l_line := l_line || 'NULL';
            ELSE
              l_line := l_line || 'TO_DATE(''' || TO_CHAR(l_val_d, 'YYYY-MM-DD HH24:MI:SS') || ''',''YYYY-MM-DD HH24:MI:SS'')';
            END IF;
          WHEN 180 THEN
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_ts);
            IF l_val_ts IS NULL THEN
              l_line := l_line || 'NULL';
            ELSE
              l_line := l_line || 'TO_TIMESTAMP(''' || TO_CHAR(l_val_ts, 'YYYY-MM-DD HH24:MI:SS.FF6') || ''',''YYYY-MM-DD HH24:MI:SS.FF6'')';
            END IF;
          WHEN 181 THEN
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_ts);
            IF l_val_ts IS NULL THEN
              l_line := l_line || 'NULL';
            ELSE
              l_line := l_line || 'TO_TIMESTAMP(''' || TO_CHAR(l_val_ts, 'YYYY-MM-DD HH24:MI:SS.FF6') || ''',''YYYY-MM-DD HH24:MI:SS.FF6'')';
            END IF;
          WHEN 231 THEN
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_ts);
            IF l_val_ts IS NULL THEN
              l_line := l_line || 'NULL';
            ELSE
              l_line := l_line || 'TO_TIMESTAMP(''' || TO_CHAR(l_val_ts, 'YYYY-MM-DD HH24:MI:SS.FF6') || ''',''YYYY-MM-DD HH24:MI:SS.FF6'')';
            END IF;
          ELSE
            DBMS_SQL.COLUMN_VALUE(l_cur, i, l_val_v);
            IF l_val_v IS NULL THEN
              l_line := l_line || 'NULL';
            ELSE
              l_line := l_line || '''' || REPLACE(l_val_v, '''', '''''') || '''';
            END IF;
        END CASE;
        IF i < l_cnt THEN l_line := l_line || ','; END IF;
      END LOOP;
      l_line := l_line || ');';
      DBMS_OUTPUT.PUT_LINE(l_line);
    END LOOP;

    DBMS_SQL.CLOSE_CURSOR(l_cur);
    DBMS_OUTPUT.PUT_LINE(' ');
  EXCEPTION
    WHEN OTHERS THEN
      IF DBMS_SQL.IS_OPEN(l_cur) THEN
        DBMS_SQL.CLOSE_CURSOR(l_cur);
      END IF;
      DBMS_OUTPUT.PUT_LINE('-- FAILED on ' || p_table || ': ' || SQLERRM);
  END dump_table;

BEGIN
  FOR t IN (
    SELECT COLUMN_VALUE AS tbl FROM TABLE(SYS.ODCIVARCHAR2LIST(
      'CORE_YEARS','REF_COUNTRIES','REF_CITIES','REF_JOBS',
      'FLEET_REF_BIKE_STATUSES','FLEET_REF_COLORS','FLEET_REF_CUSTODY_TYPES',
      'FLEET_REF_CUSTODY_LOCATIONS','FLEET_REF_DOC_TYPES','FLEET_REF_MODELS',
      'FLEET_SIM_OPERATORS','FLEET_SIM_STATUS_MASTER',
      'HR_DOC_TYPE_MASTER','HR_HIRING_SOURCE_MASTER','HR_ORG_DOC_TYPE_MASTER',
      'HR_PAY_MODE_MASTER','HR_PRO_DEAL_INCL_MASTER','HR_PRO_DEAL_TYPE_MASTER',
      'HR_STATUS_MASTER',
      'SEC_MODULES','SEC_PERMS','SEC_ROLES','SEC_ROLE_PERMS','SEC_MENU',
      'SEC_USERS','SEC_USER_ROLES'
    ))
  ) LOOP
    dump_table(t.tbl);
  END LOOP;
END;
/
