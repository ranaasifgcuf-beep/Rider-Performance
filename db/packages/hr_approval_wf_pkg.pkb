create or replace package body hr_approval_wf_pkg as

    ----------------------------------------------------------------------
    -- PRIVATE: Get APEX task ID linked with approval step
    ----------------------------------------------------------------------
    function get_task_id_by_step (
        p_approval_step_id in number
    ) return number
    is
        l_task_id number;
    begin
        select max(task_id)
          into l_task_id
          from apex_tasks
         where detail_pk = to_char(p_approval_step_id);

        return l_task_id;

    exception
        when others then
            return null;
    end get_task_id_by_step;


    ----------------------------------------------------------------------
    -- PRIVATE: Get active users by SEC role
    ----------------------------------------------------------------------
    function get_role_users (
        p_role_code in varchar2
    ) return varchar2
    is
        l_users varchar2(4000);
    begin
        select listagg(user_name, ',') within group (order by user_name)
          into l_users
          from vw_sec_role_users
         where upper(role_code) = upper(p_role_code);

        if l_users is null then
            raise_application_error(
                -20150,
                'No active SEC_USERS found for SEC_ROLE: ' || p_role_code
            );
        end if;

        return l_users;
    end get_role_users;


    ----------------------------------------------------------------------
    -- PRIVATE: Resolve approver users
    ----------------------------------------------------------------------
    function get_approver_users (
        p_approver_type      in varchar2,
        p_approver_user_name in varchar2,
        p_approver_role_code in varchar2
    ) return varchar2
    is
        l_dummy number;
    begin
        if upper(p_approver_type) = 'USER' then

            select count(*)
              into l_dummy
              from vw_sec_apex_users
             where upper(user_name) = upper(p_approver_user_name);

            if l_dummy = 0 then
                raise_application_error(
                    -20151,
                    'Approver user is not active in SEC_USERS: ' || p_approver_user_name
                );
            end if;

            return upper(p_approver_user_name);

        elsif upper(p_approver_type) = 'ROLE' then

            return get_role_users(p_approver_role_code);

        else
            raise_application_error(
                -20152,
                'Invalid approver type: ' || p_approver_type
            );
        end if;
    end get_approver_users;


    ----------------------------------------------------------------------
    -- PRIVATE: Find matching approval rule
    ----------------------------------------------------------------------
    function find_rule (
        p_module_code   in varchar2,
        p_txn_type_code in varchar2,
        p_org_id        in number,
        p_amount        in number
    ) return number
    is
        l_rule_id number;
    begin
        select rule_id
          into l_rule_id
          from (
                select r.rule_id,
                       case when r.org_id = p_org_id then 1 else 0 end org_match,
                       case when r.txn_type_code = p_txn_type_code then 1 else 0 end type_match,
                       nvl(r.seq_no, 9999) seq_no
                  from hr_approval_rules r
                 where r.module_code = p_module_code
                   and r.is_active = 'Y'
                   and (r.txn_type_code is null or r.txn_type_code = p_txn_type_code)
                   and (r.org_id is null or r.org_id = p_org_id)
                   and nvl(p_amount, 0) between nvl(r.min_amount, 0)
                                            and nvl(r.max_amount, 999999999)
               )
         order by org_match desc,
                  type_match desc,
                  seq_no
         fetch first 1 row only;

        return l_rule_id;

    exception
        when no_data_found then
            raise_application_error(
                -20101,
                'No approval rule found for module=' || p_module_code ||
                ', type=' || p_txn_type_code ||
                ', org=' || p_org_id ||
                ', amount=' || p_amount
            );
    end find_rule;


    ----------------------------------------------------------------------
    -- PUBLIC: Start approval request and APEX workflow
    ----------------------------------------------------------------------
    procedure start_approval (
        p_module_code   in varchar2,
        p_record_pk     in number,
        p_txn_type_code in varchar2,
        p_org_id        in number,
        p_amount        in number,
        p_subject       in varchar2,
        p_approval_id   out number
    )
    is
        l_rule_id        number;
        l_workflow_id    number;
        l_step_count     number;
        l_approver_users varchar2(4000);
    begin
        l_rule_id := find_rule(
            p_module_code   => p_module_code,
            p_txn_type_code => p_txn_type_code,
            p_org_id        => p_org_id,
            p_amount        => p_amount
        );

        insert into hr_approval_requests (
            module_code,
            record_pk,
            txn_type_code,
            org_id,
            approval_subject,
            approval_amount,
            rule_id,
            request_status,
            final_action_done,
            requested_by,
            requested_dt,
            created_by,
            created_dt
        )
        values (
            p_module_code,
            p_record_pk,
            p_txn_type_code,
            p_org_id,
            p_subject,
            p_amount,
            l_rule_id,
            'SUBMITTED',
            'N',
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
        )
        returning approval_id into p_approval_id;


        /*
          IMPORTANT:
          Do not use GET_APPROVER_USERS inside INSERT SELECT.
          Private package functions cannot be used in SQL.
          Therefore we insert steps using a PL/SQL loop.
        */
        for s in (
            select step_seq,
                   step_name,
                   approver_type,
                   approver_user_name,
                   approver_role_code
              from hr_approval_rule_steps
             where rule_id = l_rule_id
             order by step_seq
        )
        loop
            l_approver_users := get_approver_users(
                p_approver_type      => s.approver_type,
                p_approver_user_name => s.approver_user_name,
                p_approver_role_code => s.approver_role_code
            );

            insert into hr_approval_request_steps (
                approval_id,
                step_seq,
                step_name,
                approver_type,
                approver_user_name,
                approver_role_code,
                approver_users,
                step_status,
                created_by,
                created_dt
            )
            values (
                p_approval_id,
                s.step_seq,
                s.step_name,
                s.approver_type,
                s.approver_user_name,
                s.approver_role_code,
                l_approver_users,
                'PENDING',
                nvl(sys_context('APEX$SESSION','APP_USER'), user),
                cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
            );
        end loop;


        select count(*)
          into l_step_count
          from hr_approval_request_steps
         where approval_id = p_approval_id;

        if l_step_count = 0 then
            raise_application_error(
                -20153,
                'Approval rule found, but no approval steps are defined. Rule ID: ' || l_rule_id
            );
        end if;


        insert into hr_approval_action_log (
            approval_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            p_approval_id,
            'SUBMITTED',
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            'Approval submitted and workflow started.'
        );


        l_workflow_id := apex_workflow.start_workflow(
            p_application_id => apex_application.g_flow_id,
            p_static_id      => 'WF_UNIFIED_APPROVAL',
            p_parameters     => apex_workflow.t_workflow_parameters(
                1 => apex_workflow.t_workflow_parameter(
                        static_id    => 'APPROVAL_ID',
                        string_value => to_char(p_approval_id)
                     )
            ),
            p_initiator      => nvl(sys_context('APEX$SESSION','APP_USER'), user),
            p_detail_pk      => to_char(p_approval_id)
        );


        update hr_approval_requests
           set workflow_id = l_workflow_id,
               updated_by  = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt  = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_id = p_approval_id;

    exception
        when others then
            raise;
    end start_approval;


    ----------------------------------------------------------------------
    -- PUBLIC: Get next pending approval step for workflow
    ----------------------------------------------------------------------
    procedure get_next_step (
        p_approval_id     in number,
        p_step_id         out number,
        p_approver_users  out varchar2,
        p_task_subject    out varchar2,
        p_module_code     out varchar2,
        p_record_pk       out number
    )
    is
    begin
        select s.approval_step_id,
               s.approver_users,
               r.approval_subject,
               r.module_code,
               r.record_pk
          into p_step_id,
               p_approver_users,
               p_task_subject,
               p_module_code,
               p_record_pk
          from hr_approval_request_steps s
          join hr_approval_requests r
            on r.approval_id = s.approval_id
         where s.approval_id = p_approval_id
           and s.step_status = 'PENDING'
         order by s.step_seq
         fetch first 1 row only;


        update hr_approval_request_steps
           set step_status = 'TASK_CREATED',
               updated_by  = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt  = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_step_id = p_step_id;


        insert into hr_approval_action_log (
            approval_id,
            approval_step_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            p_approval_id,
            p_step_id,
            'TASK_CREATED',
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            'Workflow created task for current approval step.'
        );

    exception
        when no_data_found then
            raise_application_error(
                -20154,
                'No pending approval step found for Approval ID: ' || p_approval_id
            );
    end get_next_step;


    ----------------------------------------------------------------------
    -- PUBLIC: Mark approval step approved
    ----------------------------------------------------------------------
    procedure mark_step_approved (
        p_step_id       in number,
        p_approver_user in varchar2,
        p_comments      in varchar2,
        p_has_next_step out varchar2
    )
    is
        l_approval_id number;
        l_count       number;
        l_task_id     number;
    begin
        l_task_id := get_task_id_by_step(p_step_id);

        update hr_approval_request_steps
           set step_status  = 'APPROVED',
               apex_task_id = l_task_id,
               action_by    = p_approver_user,
               action_dt    = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               comments     = p_comments,
               updated_by   = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt   = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_step_id = p_step_id
           and step_status = 'TASK_CREATED'
         returning approval_id into l_approval_id;


        insert into hr_approval_action_log (
            approval_id,
            approval_step_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            l_approval_id,
            p_step_id,
            'APPROVED',
            p_approver_user,
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            p_comments
        );


        select count(*)
          into l_count
          from hr_approval_request_steps
         where approval_id = l_approval_id
           and step_status = 'PENDING';

        p_has_next_step := case when l_count > 0 then 'Y' else 'N' end;

    exception
        when no_data_found then
            raise_application_error(
                -20155,
                'Approval step is not in TASK_CREATED status or does not exist. Step ID: ' || p_step_id
            );
    end mark_step_approved;


    ----------------------------------------------------------------------
    -- PUBLIC: Mark approval step rejected
    ----------------------------------------------------------------------
    procedure mark_step_rejected (
        p_step_id       in number,
        p_approver_user in varchar2,
        p_comments      in varchar2
    )
    is
        l_approval_id number;
        l_task_id     number;
    begin
        l_task_id := get_task_id_by_step(p_step_id);

        update hr_approval_request_steps
           set step_status  = 'REJECTED',
               apex_task_id = l_task_id,
               action_by    = p_approver_user,
               action_dt    = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               comments     = p_comments,
               updated_by   = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt   = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_step_id = p_step_id
           and step_status = 'TASK_CREATED'
         returning approval_id into l_approval_id;


        update hr_approval_request_steps
           set step_status = 'CANCELLED',
               updated_by  = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt  = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_id = l_approval_id
           and step_status = 'PENDING';


        insert into hr_approval_action_log (
            approval_id,
            approval_step_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            l_approval_id,
            p_step_id,
            'REJECTED',
            p_approver_user,
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            p_comments
        );

    exception
        when no_data_found then
            raise_application_error(
                -20156,
                'Approval step is not in TASK_CREATED status or does not exist. Step ID: ' || p_step_id
            );
    end mark_step_rejected;


    ----------------------------------------------------------------------
    -- PUBLIC: Final approval after all steps are approved
    ----------------------------------------------------------------------
    procedure final_approve (
        p_approval_id in number
    )
    is
        l_module_code varchar2(50);
        l_record_pk   number;
    begin
        update hr_approval_requests
           set request_status    = 'APPROVED',
               final_action_done = 'Y',
               updated_by        = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt        = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_id = p_approval_id
           and request_status = 'SUBMITTED'
           and nvl(final_action_done, 'N') = 'N';


        if sql%rowcount = 0 then
            raise_application_error(
                -20201,
                'Approval request is already completed or not in SUBMITTED status. Approval ID: ' || p_approval_id
            );
        end if;


        select module_code,
               record_pk
          into l_module_code,
               l_record_pk
          from hr_approval_requests
         where approval_id = p_approval_id;


        hr_approval_ui_pkg.final_approve_module(
            p_module_code => l_module_code,
            p_record_pk   => l_record_pk,
            p_approval_id => p_approval_id,
            p_comments    => null
        );


        insert into hr_approval_action_log (
            approval_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            p_approval_id,
            'FINAL_APPROVED',
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            'Final approval completed.'
        );

    exception
        when no_data_found then
            raise_application_error(
                -20202,
                'Approval request not found. Approval ID: ' || p_approval_id
            );
    end final_approve;


    ----------------------------------------------------------------------
    -- PUBLIC: Final rejection after any step is rejected
    ----------------------------------------------------------------------
    procedure final_reject (
        p_approval_id in number,
        p_reason      in varchar2
    )
    is
        l_module_code varchar2(50);
        l_record_pk   number;
    begin
        update hr_approval_requests
           set request_status    = 'REJECTED',
               final_action_done = 'Y',
               updated_by        = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt        = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where approval_id = p_approval_id
           and request_status = 'SUBMITTED'
           and nvl(final_action_done, 'N') = 'N';


        if sql%rowcount = 0 then
            raise_application_error(
                -20203,
                'Approval request is already completed or not in SUBMITTED status. Approval ID: ' || p_approval_id
            );
        end if;


        select module_code,
               record_pk
          into l_module_code,
               l_record_pk
          from hr_approval_requests
         where approval_id = p_approval_id;


        hr_approval_ui_pkg.final_reject_module(
            p_module_code => l_module_code,
            p_record_pk   => l_record_pk,
            p_approval_id => p_approval_id,
            p_comments    => p_reason
        );


        insert into hr_approval_action_log (
            approval_id,
            action_code,
            action_by,
            action_dt,
            comments
        )
        values (
            p_approval_id,
            'FINAL_REJECTED',
            nvl(sys_context('APEX$SESSION','APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
            p_reason
        );

    exception
        when no_data_found then
            raise_application_error(
                -20204,
                'Approval request not found. Approval ID: ' || p_approval_id
            );
    end final_reject;

end hr_approval_wf_pkg;
/
