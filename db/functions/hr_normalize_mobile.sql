create or replace function hr_normalize_mobile (
    p_mobile in varchar2
) return varchar2 deterministic
is
    l_mobile varchar2(30);
begin
    l_mobile := regexp_replace(p_mobile, '[^0-9]', '');

    if l_mobile is null then
        return null;
    end if;

    -- 00971569011548 becomes 971569011548
    if substr(l_mobile, 1, 5) = '00971' then
        l_mobile := substr(l_mobile, 3);

    -- 0569011548 becomes 971569011548
    elsif substr(l_mobile, 1, 2) = '05'
          and length(l_mobile) = 10 then
        l_mobile := '971' || substr(l_mobile, 2);

    -- 569011548 becomes 971569011548
    elsif substr(l_mobile, 1, 1) = '5'
          and length(l_mobile) = 9 then
        l_mobile := '971' || l_mobile;
    end if;

    return l_mobile;
end;
/
