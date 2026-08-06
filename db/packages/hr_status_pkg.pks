create or replace package              hr_status_pkg as
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
  );

  /* procedure set_legal_status(
    p_emp_id number,
    p_status_code varchar2,
    p_effective_from date default trunc(sysdate),
    p_reason varchar2 default null,
    p_remarks varchar2 default null
  );*/
end;
/
