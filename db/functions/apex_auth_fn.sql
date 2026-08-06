create or replace function              apex_auth_fn(
  p_username in varchar2,
  p_password in varchar2
) return boolean
is
begin
  return wksp_alnajah.sec_auth_pkg.authenticate(p_username, p_password);
end;
/
