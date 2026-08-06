CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_SEC_APEX_USERS" ("USER_ID", "USER_NAME") AS 
  select u.user_id,
       upper(u.username) as user_name
from sec_users u
where nvl(u.is_active,'Y') = 'Y';
