create or replace package body              sec_ctx as
 function username return varchar2 is
 begin
 return upper(nvl(v('APP_USER'), user));
 end;
 function user_id return number is
 l_user_id sec_users.user_id%type;
 begin
 select u.user_id
 into l_user_id
 from sec_users u
 where u.username = sec_ctx.username
 and u.is_active = 'Y';
 return l_user_id;
 exception
 when no_data_found then
 return null;
 end;
end sec_ctx;
/
