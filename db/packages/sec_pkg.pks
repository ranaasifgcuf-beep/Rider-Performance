create or replace package              sec_pkg as
 function has_perm(p_perm_code varchar2) return number;
 function has_role(p_role_id number) return number;
 --function page_allowed(p_app_id number, p_page_id number) return number;
 function is_org_allowed(p_org_id number) return number;
 function is_project_allowed(p_project_id number) return number;
 --function is_dept_allowed(p_dept_id number) return number;
 procedure audit(p_module varchar2, p_action varchar2, p_record_key
varchar2, p_details clob);
end sec_pkg;
/
