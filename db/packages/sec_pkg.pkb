create or replace PACKAGE BODY              SEC_PKG AS

  function has_role(p_role_id number) return number is
    l_cnt number;
  begin
    select count(*)
      into l_cnt
      from sec_user_roles ur
      join sec_users u
        on u.user_id = ur.user_id
      join sec_roles r
        on r.role_id = ur.role_id
     where upper(u.username) = upper(v('APP_USER'))
       and u.is_active = 'Y'
       and r.is_active = 'Y'
       and upper(r.role_id) = upper(p_role_id);

    return case when l_cnt > 0 then 1 else 0 end;
  exception
    when others then
      return 0;
  end;

    FUNCTION HAS_PERM (
        P_PERM_CODE VARCHAR2
    ) RETURN NUMBER IS
        L_CNT NUMBER;
    BEGIN
        SELECT
            COUNT(*)
        INTO L_CNT
        FROM
                 SEC_USER_ROLES UR
            JOIN SEC_ROLE_PERMS RP ON RP.ROLE_ID = UR.ROLE_ID
            JOIN SEC_PERMS      P ON P.PERM_ID = RP.PERM_ID
        WHERE
                UR.USER_ID = SEC_CTX.USER_ID
            AND P.PERM_CODE = UPPER(P_PERM_CODE)
            AND P.IS_ACTIVE = 'Y';

        RETURN
            CASE
                WHEN L_CNT > 0 THEN
                    1
                ELSE
                    0
            END;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;

  /*function page_allowed(p_app_id number, p_page_id number) return number is
    l_perm_code sec_page_access.perm_code%type;
  begin
    select perm_code
      into l_perm_code
      from sec_page_access
     where app_id = p_app_id
       and page_id = p_page_id
       and is_active = 'Y';

    return has_perm(l_perm_code);
  exception
    when no_data_found then
      -- if not mapped, deny by default (secure by default)
      return 0;
  end;*/

    FUNCTION IS_ORG_ALLOWED (
        P_ORG_ID NUMBER
    ) RETURN NUMBER IS
        L_ALL CHAR(1);
        L_CNT NUMBER;
    BEGIN
        SELECT
            COUNT(*)
        INTO L_CNT
        FROM
            SEC_USER_ORGS
        WHERE
                USER_ID = SEC_CTX.USER_ID
            AND ORG_ID = P_ORG_ID;

    -- If you want "no rows means ALL", switch logic accordingly.
        RETURN
            CASE
                WHEN L_CNT > 0 THEN
                    1
                ELSE
                    0
            END;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;

    FUNCTION IS_PROJECT_ALLOWED (
        P_PROJECT_ID NUMBER
    ) RETURN NUMBER IS
        L_ALL CHAR(1);
        L_CNT NUMBER;
    BEGIN

        SELECT
            COUNT(*)
        INTO L_CNT
        FROM
            SEC_USER_PROJECTS
        WHERE
                USER_ID = SEC_CTX.USER_ID
            AND PROJECT_ID = P_PROJECT_ID;

        RETURN
            CASE
                WHEN L_CNT > 0 THEN
                    1
                ELSE
                    0
            END;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END;

  /*function is_dept_allowed(p_dept_id number) return number is
    l_cnt number;
  begin
    if p_dept_id is null then return 1; end if;

    select count(*) into l_cnt
      from sec_user_depts
     where user_id = sec_ctx.user_id
       and dept_id = p_dept_id;

    -- If you don't use dept scope, you can always return 1.
    return case when l_cnt > 0 then 1 else 0 end;
  exception
    when others then return 0;
  end;*/

    PROCEDURE AUDIT (
        P_MODULE     VARCHAR2,
        P_ACTION     VARCHAR2,
        P_RECORD_KEY VARCHAR2,
        P_DETAILS    CLOB
    ) IS
    BEGIN
        INSERT INTO SEC_AUDIT_LOG (
            MODULE,
            ACTION,
            RECORD_KEY,
            DETAILS,
            CHANGED_BY
        ) VALUES ( P_MODULE,
                   P_ACTION,
                   P_RECORD_KEY,
                   P_DETAILS,
                   SEC_CTX.USERNAME );

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

END SEC_PKG;
/
