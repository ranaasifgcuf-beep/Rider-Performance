create or replace package body              sec_auth_pkg as

  function hash_pwd(p_password varchar2, p_salt varchar2) return varchar2 is
    l_raw raw(2000);
  begin
    l_raw :=
      dbms_crypto.hash(
        utl_raw.cast_to_raw(upper(p_password) || ':' || p_salt),
        dbms_crypto.hash_sh256
      );

    return rawtohex(l_raw);
  end;

  procedure set_password(
    p_username    varchar2,
    p_password    varchar2,
    p_must_change char default 'N'
  ) is
    l_salt varchar2(200);
  begin
    l_salt := rawtohex(sys_guid());

    update sec_users
       set password_salt  = l_salt,
           password_hash  = hash_pwd(p_password, l_salt),
           pwd_changed_on = sysdate,
           must_change    = nvl(p_must_change,'N')
     where upper(username) = upper(p_username);

    if sql%rowcount = 0 then
      raise_application_error(-20001, 'User not found: '||p_username);
    end if;
  end;

  function authenticate(
    p_username varchar2,
    p_password varchar2
  ) return boolean is
    l_salt sec_users.password_salt%type;
    l_hash sec_users.password_hash%type;
  begin
    select password_salt, password_hash
      into l_salt, l_hash
      from sec_users
     where upper(username)  = upper(p_username)
       and is_active = 'Y';

    if l_salt is null or l_hash is null then
      return false;
    end if;

    return hash_pwd(p_password, l_salt) = l_hash;

  exception
    when no_data_found then
      return false;
  end;

  procedure post_login is
    l_must_change char(1);
  begin
    update sec_users
       set last_login_on = sysdate
     where upper(username) = upper(v('APP_USER'));

   /* select must_change
      into l_must_change
      from sec_users
     where username = upper(v('APP_USER'));

    if l_must_change = 'Y' then
      apex_util.redirect_url(
        'f?p='||v('APP_ID')||':901:'||v('APP_SESSION')
      );
    end if;*/
  exception
    when others then null;
  end;

end sec_auth_pkg;
/
