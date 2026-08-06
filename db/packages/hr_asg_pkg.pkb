create or replace package body hr_asg_pkg as

  procedure validate_assignment(
    p_asg_id    number,
    p_emp_id    number,
    p_start_dt  date,
    p_end_dt    date
  ) is
    l_cnt number;
  begin
    if p_start_dt is null then
      raise_application_error(-20020, 'Start date is required.');
    end if;

    if p_end_dt is not null and p_end_dt < p_start_dt then
      raise_application_error(-20021, 'End date cannot be less than start date.');
    end if;

    /*
      Overlap logic:
      New period overlaps old period if:
      new_start <= old_end_or_highdate
      and new_end_or_highdate >= old_start
    */
    select count(*)
      into l_cnt
      from hr_assignments a
     where a.emp_id = p_emp_id
       and nvl(a.asg_id, -1) <> nvl(p_asg_id, -1)
       and p_start_dt <= nvl(a.end_dt, date '4712-12-31')
       and nvl(p_end_dt, date '4712-12-31') >= a.start_dt;

    if l_cnt > 0 then
      raise_application_error(-20022, 'Assignment date range overlaps an existing assignment.');
    end if;
  end validate_assignment;


  procedure sync_emp_status(
    p_emp_id number
  ) is
    l_current_cnt number;
    l_current_status varchar2(30);
  begin
    select count(*)
      into l_current_cnt
      from hr_assignments
     where emp_id = p_emp_id
       and end_dt is null;

    begin
      select status_code
        into l_current_status
        from hr_emp_status_hist
       where emp_id = p_emp_id
         and effective_to is null;
    exception
      when no_data_found then
        l_current_status := null;
    end;

    if nvl(l_current_cnt,0) > 0 then
      if nvl(l_current_status,'A') <> 'ACTIVE' then
        hr_status_pkg.set_status(
          p_emp_id          => p_emp_id,
          p_status_code     => 'ACTIVE',
          p_effective_from  => trunc(sysdate),
          p_reason          => 'Assignment Update',
          p_remarks         => 'Employee has active assignment'
        );
      end if;
    else
      if nvl(l_current_status,'A') <> 'OFFBOARD' then
        hr_status_pkg.set_status(
          p_emp_id          => p_emp_id,
          p_status_code     => 'OFFBOARD',
          p_effective_from  => trunc(sysdate),
          p_reason          => 'Assignment Update',
          p_remarks         => 'Employee has no active assignment'
        );
      end if;
    end if;
  end sync_emp_status;

end;
/
