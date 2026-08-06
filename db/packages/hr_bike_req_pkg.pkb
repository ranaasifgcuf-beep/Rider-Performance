create or replace package body hr_bike_req_pkg as

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

        insert into hr_bike_request_log (
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


    function create_request (
    p_emp_id               in number,
    p_request_type         in varchar2,
    p_priority             in varchar2 default 'NORMAL',
    p_required_by_dt       in date default null,
    p_requested_project_id in number default null,
    p_requested_city_id    in number default null,
    p_reason_code          in varchar2 default null,
    p_remarks              in varchar2 default null
) return number is

    l_request_id      number;
    l_open_count      number;
    l_current_bike_id number;
    l_project_id      number;
    l_city_id         number;
begin
    if p_emp_id is null then
        raise_application_error(-20001, 'Employee is required.');
    end if;

    if p_request_type is null then
        raise_application_error(-20001, 'Bike request type is required.');
    end if;

    select count(*)
      into l_open_count
      from hr_bike_requests
     where emp_id = p_emp_id
       and request_status in ('OPEN','IN_PROGRESS');

    if l_open_count > 0 then
        raise_application_error(
            -20001,
            'There is already an open bike request for this employee.'
        );
    end if;

    begin
        select bike_id
          into l_current_bike_id
          from vw_hr_emp_current_bike
         where emp_id = p_emp_id;
    exception
        when no_data_found then
            l_current_bike_id := null;
    end;

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

    insert into hr_bike_requests (
        emp_id,
        request_type,
        request_status,
        priority,
        required_by_dt,
        current_bike_id,
        requested_project_id,
        requested_city_id,
        reason_code,
        request_remarks
    )
    values (
        p_emp_id,
        upper(p_request_type),
        'OPEN',
        upper(nvl(p_priority, 'NORMAL')),
        p_required_by_dt,
        l_current_bike_id,
        l_project_id,
        l_city_id,
        upper(p_reason_code),
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


    procedure set_status (
        p_request_id in number,
        p_status     in varchar2,
        p_remarks    in varchar2 default null
    ) is
        l_old_status varchar2(30);
        l_new_status varchar2(30);
        l_user       varchar2(100);
        l_now        date;
    begin
        if p_request_id is null then
            raise_application_error(-20001, 'Request ID is required.');
        end if;

        if p_status is null then
            raise_application_error(-20001, 'Status is required.');
        end if;

        l_new_status := upper(p_status);
        l_user       := app_user;
        l_now        := uae_now;

        select request_status
          into l_old_status
          from hr_bike_requests
         where request_id = p_request_id
         for update;

        if l_old_status = l_new_status then
            return;
        end if;

        update hr_bike_requests
           set request_status   = l_new_status,
               rejection_reason = case
                                      when l_new_status = 'REJECTED'
                                      then p_remarks
                                      else rejection_reason
                                  end,
               closed_by        = case
                                      when l_new_status in ('REJECTED','CANCELLED','CLOSED')
                                      then l_user
                                      else closed_by
                                  end,
               closed_dt        = case
                                      when l_new_status in ('REJECTED','CANCELLED','CLOSED')
                                      then l_now
                                      else closed_dt
                                  end
         where request_id = p_request_id;

        add_log(
            p_request_id => p_request_id,
            p_action     => 'STATUS_CHANGE',
            p_old_status => l_old_status,
            p_new_status => l_new_status,
            p_remarks    => p_remarks
        );
    end set_status;


    procedure close_after_assignment (
        p_emp_id             in number,
        p_bike_id            in number default null,
        p_bike_assignment_id in number default null,
        p_request_id         in number default null
    ) is
        l_request_id number;
        l_old_status varchar2(30);
        l_bike_id    number;
        l_user       varchar2(100);
        l_now        date;
    begin
        if p_emp_id is null then
            return;
        end if;

        l_user := app_user;
        l_now  := uae_now;

        l_request_id := p_request_id;

        if l_request_id is null then
            begin
                select request_id
                  into l_request_id
                  from (
                        select request_id
                          from hr_bike_requests
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

        l_bike_id := p_bike_id;

        if l_bike_id is null then
            begin
                select bike_id
                  into l_bike_id
                  from vw_hr_emp_current_bike
                 where emp_id = p_emp_id;
            exception
                when no_data_found then
                    l_bike_id := null;
            end;
        end if;

        select request_status
          into l_old_status
          from hr_bike_requests
         where request_id = l_request_id
         for update;

        update hr_bike_requests
           set request_status     = 'ASSIGNED',
               assigned_bike_id   = l_bike_id,
               bike_assignment_id = p_bike_assignment_id,
               closed_by          = l_user,
               closed_dt          = l_now
         where request_id = l_request_id;

        add_log(
            p_request_id => l_request_id,
            p_action     => 'ASSIGNED',
            p_old_status => l_old_status,
            p_new_status => 'ASSIGNED',
            p_remarks    => 'Bike assigned and request closed'
        );
    end close_after_assignment;

end hr_bike_req_pkg;
/
