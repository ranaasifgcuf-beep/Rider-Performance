create or replace package body              sec_user_ops_pkg as
  procedure change_my_password(p_old varchar2, p_new varchar2) is
  begin
    if not sec_auth_pkg.authenticate(v('APP_USER'), p_old) then
      raise_application_error(-20010, 'Old password is incorrect.'||v('APP_USER'));
    end if;

    sec_auth_pkg.set_password(v('APP_USER'), p_new, 'N');
  end;
end;
/
