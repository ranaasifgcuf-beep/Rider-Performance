create or replace package              sec_auth_pkg as
  function hash_pwd(p_password varchar2, p_salt varchar2) return varchar2;

  procedure set_password(
    p_username    varchar2,
    p_password    varchar2,
    p_must_change char default 'N'
  );

  function authenticate(
    p_username varchar2,
    p_password varchar2
  ) return boolean;

  procedure post_login; -- update last login + redirect if must_change=Y (optional)
end sec_auth_pkg;
/
