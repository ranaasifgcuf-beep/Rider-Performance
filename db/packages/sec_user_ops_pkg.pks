create or replace package              sec_user_ops_pkg as
  procedure change_my_password(p_old varchar2, p_new varchar2);
end;
/
