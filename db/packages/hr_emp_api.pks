create or replace package              hr_emp_api as
  procedure change_status(
    p_emp_id         number,
    p_action_type    varchar2,
    p_target_status  varchar2,
    p_reason         varchar2 := null,
    p_amount         number   := null,
    p_effective_dt   date     := trunc(sysdate),
    p_attachment_ref varchar2 := null
  );
end;
/
