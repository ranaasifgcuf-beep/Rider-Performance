create or replace package hr_emp_pkg as
  function can_change_status(
    p_role_code   varchar2,
    p_status_code varchar2
  ) return varchar2;

  procedure apply_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date default trunc(sysdate),
    p_reason          varchar2 default null,
    p_remarks         varchar2 default null,
    p_role_code       varchar2,
    P_PROJECT_ID NUMBER default null,
    P_CITY_ID NUMBER default null,
    P_LEAVE_START DATE default null,
    P_LEAVE_END DATE default null,
    P_LEAVE_TYPE varchar2 default null
  );

  procedure set_system_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date default trunc(sysdate),
    p_reason          varchar2 default null,
    p_remarks         varchar2 default null
  );

 procedure change_legal_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date default trunc(sysdate),
    p_reason          varchar2 default null,
    p_remarks         varchar2 default null,
    p_role_code       varchar2
  );

  procedure set_system_legal_status(
    p_emp_id          number,
    p_new_status_code varchar2,
    p_effective_from  date default trunc(sysdate),
    p_reason          varchar2 default null,
    p_remarks         varchar2 default null
  );

end;
/
