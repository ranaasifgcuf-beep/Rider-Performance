create or replace package hr_asg_pkg as

  procedure validate_assignment(
    p_asg_id    number,
    p_emp_id    number,
    p_start_dt  date,
    p_end_dt    date
  );

  procedure sync_emp_status(
    p_emp_id number
  );

end;
/
