create or replace package body              hr_emp_api as
  procedure change_status(
    p_emp_id         number,
    p_action_type    varchar2,
    p_target_status  varchar2,
    p_reason         varchar2,
    p_amount         number,
    p_effective_dt   date,
    p_attachment_ref varchar2
  ) is
    l_user varchar2(100) := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    l_ok   number;
  begin
    -- ACL check: user must have any role allowed for this status
    select count(*)
      into l_ok
      from hr_status_acl a
     where a.status_code = upper(trim(p_target_status))
       and a.can_set='Y'
       and a.is_active='Y'
       and exists (
         select 1
           from sec_user_roles ur
          where upper(ur.user_id)  = sec_ctx.user_id
            and (ur.role_id) = (a.role_code)
       );

    if l_ok = 0 then
      raise_application_error(-20010, 'Not allowed to set status '||upper(trim(p_target_status))||'.');
    end if;

    insert into hr_emp_actions(emp_id, action_type, target_status, action_dt, amount, remarks, attachment_ref, status)
    values (p_emp_id,
            upper(trim(p_action_type)),
            upper(trim(p_target_status)),
            p_effective_dt,
            p_amount,
            p_reason,
            p_attachment_ref,
            'DONE');

    hr_status_pkg.set_status(
      p_emp_id         => p_emp_id,
      p_status_code    => p_target_status,
      p_effective_from => p_effective_dt,
      p_reason         => p_action_type,
      p_remarks        => 'Manual (no approval) by '||l_user||case when p_reason is not null then ' | '||p_reason end
    );
  end;
end;
/
