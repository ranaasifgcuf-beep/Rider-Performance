create or replace package body hr_sim_req_pkg as

    ----------------------------------------------------------------------
    -- Common helpers
    ----------------------------------------------------------------------
    function app_user return varchar2 is
    begin
        return nvl(sys_context('APEX$SESSION','APP_USER'), user);
    end app_user;


    function uae_now return date is
    begin
        return cast(systimestamp at time zone 'Asia/Dubai' as date);
    end uae_now;


    procedure add_log (
        p_request_id in number,
        p_action     in varchar2,
        p_old_status in varchar2,
        p_new_status in varchar2,
        p_remarks    in varchar2 default null
    ) is
        l_user varchar2(100);
        l_now  date;
    begin
        l_user := app_user;
        l_now  := uae_now;

        insert into hr_sim_request_log (
            request_id,
            action_code,
            old_status,
            new_status,
            remarks,
            action_by,
            action_dt
        )
        values (
            p_request_id,
            p_action,
            p_old_status,
            p_new_status,
            p_remarks,
            l_user,
            l_now
        );
    end add_log;


    ----------------------------------------------------------------------
    -- Validate request type
    ----------------------------------------------------------------------
    procedure validate_request_type (
        p_request_type in varchar2
    ) is
        l_type varchar2(50);
    begin
        l_type := upper(trim(p_request_type));

        if l_type not in (
            'NEW_ONBOARDING',
            'ADDITIONAL_SIM',
            'REPLACEMENT_LOST',
            'REPLACEMENT_DAMAGED',
            'REPLACEMENT_BLOCKED',
            'REPLACEMENT_PROJECT_CHANGE',
            'TEMPORARY_REPLACEMENT',
            'RETURN_REQUEST',
            'OTHER'
        ) then
            raise_application_error(
                -20001,
                'Invalid SIM request type: ' || p_request_type
            );
        end if;
    end validate_request_type;


    ----------------------------------------------------------------------
    -- Validate priority
    ----------------------------------------------------------------------
    procedure validate_priority (
        p_priority in varchar2
    ) is
        l_priority varchar2(20);
    begin
        l_priority := upper(trim(nvl(p_priority, 'NORMAL')));

        if l_priority not in ('LOW','NORMAL','HIGH','URGENT') then
            raise_application_error(
                -20001,
                'Invalid priority: ' || p_priority
            );
        end if;
    end validate_priority;


    ----------------------------------------------------------------------
    -- Resolve current SIM
    -- Required for replacement / return cases.
    -- If employee has multiple active SIMs, selected SIM is mandatory.
    ----------------------------------------------------------------------
    function resolve_current_sim (
        p_emp_id         in number,
        p_request_type   in varchar2,
        p_current_sim_id in number default null
    ) return number is
        l_type   varchar2(50);
        l_cnt    number;
        l_sim_id number;
    begin
        l_type := upper(trim(p_request_type));

        if p_current_sim_id is not null then
            select count(*)
              into l_cnt
              from vw_hr_emp_current_sims
             where emp_id = p_emp_id
               and sim_id = p_current_sim_id;

            if l_cnt = 0 then
                raise_application_error(
                    -20001,
                    'Selected current SIM is not actively assigned to this employee.'
                );
            end if;

            return p_current_sim_id;
        end if;

        if l_type in (
            'REPLACEMENT_LOST',
            'REPLACEMENT_DAMAGED',
            'REPLACEMENT_BLOCKED',
            'REPLACEMENT_PROJECT_CHANGE',
            'TEMPORARY_REPLACEMENT',
            'RETURN_REQUEST'
        ) then

            select count(*)
              into l_cnt
              from vw_hr_emp_current_sims
             where emp_id = p_emp_id;

            if l_cnt = 0 then
                raise_application_error(
                    -20001,
                    'Employee has no active SIM. Current SIM is required for this request type.'
                );

            elsif l_cnt > 1 then
                raise_application_error(
                    -20001,
                    'Employee has multiple active SIMs. Please select the current SIM for this request.'
                );
            end if;

            select sim_id
              into l_sim_id
              from vw_hr_emp_current_sims
             where emp_id = p_emp_id;

            return l_sim_id;
        end if;

        return null;
    end resolve_current_sim;


    ----------------------------------------------------------------------
    -- Create SIM request
    ----------------------------------------------------------------------
    function create_request (
        p_emp_id               in number,
        p_request_type         in varchar2,
        p_priority             in varchar2 default 'NORMAL',
        p_required_by_dt       in date default null,
        p_requested_project_id in number default null,
        p_requested_city_id    in number default null,
        p_current_sim_id       in number default null,
        p_reason_code          in varchar2 default null,
        p_remarks              in varchar2 default null
    ) return number is
        l_request_id     number;
        l_open_count     number;
        l_project_id     number;
        l_city_id        number;
        l_current_sim_id number;
        l_type           varchar2(50);
        l_priority       varchar2(20);
    begin
        if p_emp_id is null then
            raise_application_error(-20001, 'Employee is required.');
        end if;

        if p_request_type is null then
            raise_application_error(-20001, 'SIM request type is required.');
        end if;

        l_type     := upper(trim(p_request_type));
        l_priority := upper(trim(nvl(p_priority, 'NORMAL')));

        validate_request_type(l_type);
        validate_priority(l_priority);

        ------------------------------------------------------------------
        -- One open SIM request per employee
        ------------------------------------------------------------------
        select count(*)
          into l_open_count
          from hr_sim_requests
         where emp_id = p_emp_id
           and request_status in ('OPEN','IN_PROGRESS');

        if l_open_count > 0 then
            raise_application_error(
                -20001,
                'There is already an open SIM request for this employee.'
            );
        end if;

        ------------------------------------------------------------------
        -- Resolve current SIM for replacement / return
        ------------------------------------------------------------------
        l_current_sim_id := resolve_current_sim(
                                p_emp_id         => p_emp_id,
                                p_request_type   => l_type,
                                p_current_sim_id => p_current_sim_id
                            );

        ------------------------------------------------------------------
        -- Resolve project / city from current status if not passed
        ------------------------------------------------------------------
        l_project_id := p_requested_project_id;
        l_city_id    := p_requested_city_id;

        if l_project_id is null or l_city_id is null then
            begin
                select project_id,
                       city_id
                  into l_project_id,
                       l_city_id
                  from (
                        select project_id,
                               city_id
                          from hr_emp_status_hist
                         where emp_id = p_emp_id
                           and effective_to is null
                         order by effective_from desc, status_id desc
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    null;
            end;
        end if;

        ------------------------------------------------------------------
        -- Insert request
        ------------------------------------------------------------------
        insert into hr_sim_requests (
            emp_id,
            request_type,
            request_status,
            priority,
            required_by_dt,
            requested_project_id,
            requested_city_id,
            current_sim_id,
            reason_code,
            request_remarks
        )
        values (
            p_emp_id,
            l_type,
            'OPEN',
            l_priority,
            p_required_by_dt,
            l_project_id,
            l_city_id,
            l_current_sim_id,
            upper(trim(p_reason_code)),
            p_remarks
        )
        returning request_id into l_request_id;

        add_log(
            p_request_id => l_request_id,
            p_action     => 'CREATE',
            p_old_status => null,
            p_new_status => 'OPEN',
            p_remarks    => p_remarks
        );

        return l_request_id;
    end create_request;


    ----------------------------------------------------------------------
    -- Mark request In Progress
    ----------------------------------------------------------------------
    procedure mark_in_progress (
        p_request_id in number,
        p_remarks    in varchar2 default null
    ) is
        l_old_status varchar2(30);
    begin
        select request_status
          into l_old_status
          from hr_sim_requests
         where request_id = p_request_id
         for update;

        if l_old_status <> 'OPEN' then
            raise_application_error(
                -20001,
                'Only OPEN SIM requests can be marked In Progress.'
            );
        end if;

        update hr_sim_requests
           set request_status = 'IN_PROGRESS'
         where request_id = p_request_id;

        add_log(
            p_request_id => p_request_id,
            p_action     => 'IN_PROGRESS',
            p_old_status => l_old_status,
            p_new_status => 'IN_PROGRESS',
            p_remarks    => p_remarks
        );
    end mark_in_progress;


    ----------------------------------------------------------------------
    -- Cancel request
    ----------------------------------------------------------------------
    procedure cancel_request (
        p_request_id in number,
        p_reason     in varchar2 default null
    ) is
        l_old_status varchar2(30);
        l_user       varchar2(100);
        l_now        date;
    begin
        l_user := app_user;
        l_now  := uae_now;

        select request_status
          into l_old_status
          from hr_sim_requests
         where request_id = p_request_id
         for update;

        if l_old_status <> 'OPEN' then
            raise_application_error(
                -20001,
                'Only OPEN SIM requests can be cancelled.'
            );
        end if;

        update hr_sim_requests
           set request_status      = 'CANCELLED',
               cancellation_reason = p_reason,
               closed_by           = l_user,
               closed_dt           = l_now
         where request_id = p_request_id;

        add_log(
            p_request_id => p_request_id,
            p_action     => 'CANCEL',
            p_old_status => l_old_status,
            p_new_status => 'CANCELLED',
            p_remarks    => p_reason
        );
    end cancel_request;


    ----------------------------------------------------------------------
    -- Reject request
    ----------------------------------------------------------------------
    procedure reject_request (
        p_request_id in number,
        p_reason     in varchar2
    ) is
        l_old_status varchar2(30);
        l_user       varchar2(100);
        l_now        date;
    begin
        l_user := app_user;
        l_now  := uae_now;

        if p_reason is null then
            raise_application_error(-20001, 'Rejection reason is required.');
        end if;

        select request_status
          into l_old_status
          from hr_sim_requests
         where request_id = p_request_id
         for update;

        if l_old_status not in ('OPEN','IN_PROGRESS') then
            raise_application_error(
                -20001,
                'Only OPEN or IN_PROGRESS SIM requests can be rejected.'
            );
        end if;

        update hr_sim_requests
           set request_status   = 'REJECTED',
               rejection_reason = p_reason,
               closed_by        = l_user,
               closed_dt        = l_now
         where request_id = p_request_id;

        add_log(
            p_request_id => p_request_id,
            p_action     => 'REJECT',
            p_old_status => l_old_status,
            p_new_status => 'REJECTED',
            p_remarks    => p_reason
        );
    end reject_request;


    ----------------------------------------------------------------------
    -- Close after SIM assignment
    -- Called after HR_SIM_ASSIGNMENTS insert from SIM operation page.
    ----------------------------------------------------------------------
    procedure close_after_assignment (
        p_emp_id        in number,
        p_sim_id        in number default null,
        p_sim_assign_id in number default null,
        p_request_id    in number default null
    ) is
        l_request_id number;
        l_old_status varchar2(30);
        l_sim_id     number;
        l_assign_id  number;
        l_user       varchar2(100);
        l_now        date;
    begin
        l_user := app_user;
        l_now  := uae_now;

        if p_emp_id is null then
            return;
        end if;

        l_request_id := p_request_id;
        l_sim_id     := p_sim_id;
        l_assign_id  := p_sim_assign_id;

        ------------------------------------------------------------------
        -- If assignment id is passed, get SIM from assignment
        ------------------------------------------------------------------
        if l_assign_id is not null and l_sim_id is null then
            begin
                select sim_id
                  into l_sim_id
                  from hr_sim_assignments
                 where sim_assign_id = l_assign_id
                   and emp_id = p_emp_id;
            exception
                when no_data_found then
                    l_sim_id := null;
            end;
        end if;

        ------------------------------------------------------------------
        -- If request id not passed, find latest open request
        ------------------------------------------------------------------
        if l_request_id is null then
            begin
                select request_id
                  into l_request_id
                  from (
                        select request_id
                          from hr_sim_requests
                         where emp_id = p_emp_id
                           and request_status in ('OPEN','IN_PROGRESS')
                         order by requested_dt desc, request_id desc
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    return;
            end;
        end if;

        ------------------------------------------------------------------
        -- If SIM id not passed, get latest active SIM
        ------------------------------------------------------------------
        if l_sim_id is null then
            begin
                select sim_id
                  into l_sim_id
                  from (
                        select sim_id,
                               assign_dt
                          from vw_hr_emp_current_sims
                         where emp_id = p_emp_id
                         order by assign_dt desc, sim_id desc
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    l_sim_id := null;
            end;
        end if;

        select request_status
          into l_old_status
          from hr_sim_requests
         where request_id = l_request_id
         for update;

        if l_old_status not in ('OPEN','IN_PROGRESS') then
            raise_application_error(
                -20001,
                'Only OPEN or IN_PROGRESS SIM requests can be closed after assignment.'
            );
        end if;

        update hr_sim_requests
           set request_status  = 'ASSIGNED',
               assigned_sim_id = l_sim_id,
               sim_assign_id   = l_assign_id,
               closed_by       = l_user,
               closed_dt       = l_now
         where request_id = l_request_id;

        add_log(
            p_request_id => l_request_id,
            p_action     => 'ASSIGNED',
            p_old_status => l_old_status,
            p_new_status => 'ASSIGNED',
            p_remarks    => 'SIM assigned and request closed'
        );
    end close_after_assignment;


    ----------------------------------------------------------------------
    -- Close after SIM return
    -- Used for RETURN_REQUEST only.
    ----------------------------------------------------------------------
    procedure close_after_return (
        p_emp_id     in number,
        p_sim_id     in number default null,
        p_request_id in number default null,
        p_remarks    in varchar2 default null
    ) is
        l_request_id number;
        l_old_status varchar2(30);
        l_user       varchar2(100);
        l_now        date;
    begin
        l_user := app_user;
        l_now  := uae_now;

        if p_emp_id is null then
            return;
        end if;

        l_request_id := p_request_id;

        if l_request_id is null then
            begin
                select request_id
                  into l_request_id
                  from (
                        select request_id
                          from hr_sim_requests
                         where emp_id = p_emp_id
                           and request_type = 'RETURN_REQUEST'
                           and request_status in ('OPEN','IN_PROGRESS')
                           and (
                                p_sim_id is null
                                or current_sim_id = p_sim_id
                           )
                         order by requested_dt desc, request_id desc
                       )
                 where rownum = 1;
            exception
                when no_data_found then
                    return;
            end;
        end if;

        select request_status
          into l_old_status
          from hr_sim_requests
         where request_id = l_request_id
         for update;

        if l_old_status not in ('OPEN','IN_PROGRESS') then
            raise_application_error(
                -20001,
                'Only OPEN or IN_PROGRESS SIM return requests can be closed.'
            );
        end if;

        update hr_sim_requests
           set request_status = 'CLOSED',
               closed_by      = l_user,
               closed_dt      = l_now
         where request_id = l_request_id;

        add_log(
            p_request_id => l_request_id,
            p_action     => 'CLOSED',
            p_old_status => l_old_status,
            p_new_status => 'CLOSED',
            p_remarks    => nvl(p_remarks, 'SIM return request closed')
        );
    end close_after_return;

end hr_sim_req_pkg;
/
