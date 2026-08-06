create or replace package              sec_ctx as
 function username return varchar2;
 function user_id return number;
end sec_ctx;
/
