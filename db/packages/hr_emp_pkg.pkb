create or replace package body hr_emp_pkg as
----------No need for it
  function can_change_status(
    p_role_code   varchar2,
    p_status_code varchar2
  ) return varchar2
  is
    l_cnt number;
  begin
    select count(*)
      into l_cnt
      from hr_status_acl
     where upper(role_code)   = upper(p_role_code)
       and upper(status_code) = upper(p_status_code)
       and can_set = 'Y';

    return case when l_cnt > 0 then 'Y' else 'N' end;
  end;

  /*procedure change_status(
    p_emp_id number,
    p_status_code varchar2,
    p_effective_from date,
    p_reason varchar2,
    p_remarks varchar2,
    P_PROJECT_ID NUMBER,
    P_CITY_ID NUMBER,
    P_LEAVE_START DATE,
    P_LEAVE_END DATE,
    P_LEAVE_TYPE varchar2
  ) is
  begin
    update hr_emp_status_hist
       set effective_to = p_effective_from - 1
     where emp_id = p_emp_id
       and effective_to is null;

    insert into hr_emp_status_hist(emp_id, status_code, effective_from, effective_to, reason, remarks, project_id, city_id, leave_start_date, leave_end_date, leave_reason)
    values (p_emp_id, upper(trim(p_status_code)), p_effective_from, null, p_reason, p_remarks,P_PROJECT_ID,P_CITY_ID,P_LEAVE_START, P_LEAVE_END,P_LEAVE_TYPE);
  end;
*/

  procedure apply_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date,
    p_reason          varchar2,
    p_remarks         varchar2,
    p_role_code       varchar2,
     P_PROJECT_ID NUMBER,
    P_CITY_ID NUMBER,
    P_LEAVE_START DATE,
    P_LEAVE_END DATE,
    P_LEAVE_TYPE varchar2
  )
  is
    l_user_changeable char(1);
  begin
    select user_changeable
      into l_user_changeable
      from hr_status_master
     where status_code = upper(trim(p_new_status_code));

    if l_user_changeable <> 'Y' then
      raise_application_error(-20011, 'This status can only be changed by system.');
    end if;

    if can_change_status(p_role_code, p_new_status_code) <> 'Y' then
      raise_application_error(-20010, 'You are not allowed to set this status.');
    end if;

  /*  hr_status_pkg.set_status(
      p_emp_id          => p_emp_id,
      p_new_status_code => p_new_status_code,
      p_effective_from  => p_effective_from,
      p_reason          => p_reason,
      p_remarks         => p_remarks
    );
    */
  end;

  procedure set_system_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date,
    p_reason          varchar2,
    p_remarks         varchar2
  )
  is
    l_status_type varchar2(20);
  begin
    select status_type
      into l_status_type
      from hr_status_master
     where status_code = upper(trim(p_new_status_code));

    if l_status_type <> 'SYSTEM' then
      raise_application_error(-20012, 'Only system statuses are allowed in set_system_status.');
    end if;

   /* change_status(
      p_emp_id          => p_emp_id,
      p_new_status_code => p_new_status_code,
      p_effective_from  => p_effective_from,
      p_reason          => p_reason,
      p_remarks         => p_remarks
    );*/
  end;

--------- Legal Status 
procedure apply_legal_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date,
    p_reason          varchar2,
    p_remarks         varchar2
  )
  is
  begin
    update hr_emp_legal_status_hist
       set effective_to = p_effective_from - 1
     where emp_id = p_emp_id
       and effective_to is null;

    insert into hr_emp_legal_status_hist (
      emp_id,
      status_code,
      effective_from,
      effective_to,
      reason,
      remarks
    )
    values (
      p_emp_id,
      upper(trim(p_new_status_code)),
      p_effective_from,
      null,
      p_reason,
      p_remarks
    );
  end;

  procedure change_legal_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date,
    p_reason          varchar2,
    p_remarks         varchar2,
    p_role_code       varchar2
  )
  is
    l_user_changeable char(1);
  begin
    select user_changeable
      into l_user_changeable
      from hr_status_master
     where status_code = upper(trim(p_new_status_code));

    if l_user_changeable <> 'Y' then
      raise_application_error(-20011, 'This status can only be changed by system.');
    end if;

    if can_change_status(p_role_code, p_new_status_code) <> 'Y' then
      raise_application_error(-20010, 'You are not allowed to set this status.');
    end if;

    apply_legal_status(
      p_emp_id          => p_emp_id,
      p_new_status_code => p_new_status_code,
      p_effective_from  => p_effective_from,
      p_reason          => p_reason,
      p_remarks         => p_remarks
    );
  end;

  procedure set_system_legal_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date,
    p_reason          varchar2,
    p_remarks         varchar2
  )
  is
    l_status_type varchar2(20);
  begin
    select status_type
      into l_status_type
      from hr_status_master
     where status_code = upper(trim(p_new_status_code));

    if l_status_type <> 'SYSTEM' then
      raise_application_error(-20012, 'Only system statuses are allowed in set_system_status.');
    end if;

    apply_legal_status(
      p_emp_id          => p_emp_id,
      p_new_status_code => p_new_status_code,
      p_effective_from  => p_effective_from,
      p_reason          => p_reason,
      p_remarks         => p_remarks
    );
  end;

end;
/
