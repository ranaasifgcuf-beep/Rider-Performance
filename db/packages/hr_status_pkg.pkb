create or replace package body              hr_status_pkg as
  procedure set_status(
    p_emp_id number,
    p_status_code varchar2,
    p_effective_from date default trunc(sysdate),
    p_reason varchar2 default null,
    p_remarks varchar2 default null,
    P_PROJECT_ID NUMBER DEFAULT NULL,
    P_CITY_ID NUMBER DEFAULT NULL,
    P_LEAVE_START DATE DEFAULT NULL,
    P_LEAVE_END DATE DEFAULT NULL,
    P_LEAVE_TYPE varchar2 DEFAULT NULL
    /*p_emp_id number,
    p_status_code varchar2,
    p_effective_from date,
    p_reason varchar2,
    p_remarks varchar2,
    P_PROJECT_ID NUMBER,
    P_CITY_ID NUMBER,
    P_LEAVE_START DATE,
    P_LEAVE_END DATE,
    P_LEAVE_TYPE varchar2*/
  ) is
  begin
    update hr_emp_status_hist
       set effective_to = p_effective_from - 1
     where emp_id = p_emp_id
       and effective_to is null;

    insert into hr_emp_status_hist(emp_id, status_code, effective_from, effective_to, reason, remarks, project_id, city_id, leave_start_date, leave_end_date, leave_reason)
    values (p_emp_id, upper(trim(p_status_code)), p_effective_from, null, p_reason, p_remarks,P_PROJECT_ID,P_CITY_ID,P_LEAVE_START, P_LEAVE_END,P_LEAVE_TYPE);
  end;

   /* procedure set_legal_status(
    p_emp_id number,
    p_status_code varchar2,
    p_effective_from date,
    p_reason varchar2,
    p_remarks varchar2
  ) is
  begin
    update hr_emp_legal_status_hist
       set effective_to_dt = p_effective_from - 1
     where emp_id = p_emp_id
       and effective_to_dt is null;

    insert into hr_emp_legal_status_hist(emp_id, status_code, effective_from_dt, effective_to_dt, reason, remarks)
    values (p_emp_id, upper(trim(p_status_code)), p_effective_from, null, p_reason, p_remarks);
  end;*/
end;
/
