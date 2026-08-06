CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_SEC_ROLE_USERS" ("ROLE_CODE", "USER_NAME") AS 
  select r.role_code,
       upper(u.username) as user_name
from sec_user_roles ur
join sec_users u
  on u.user_id = ur.user_id
join sec_roles r
  on r.role_id = ur.role_id
where nvl(u.is_active,'Y') = 'Y'
  and nvl(r.is_active,'Y') = 'Y';
