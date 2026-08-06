create or replace package body hr_legal_status_sync_pkg as

    procedure sync_working_status (
        p_emp_id       in number,
        p_legal_status in varchar2,
        p_reason       in varchar2 default null
    ) is
        l_active_assignment number := 0;
        l_current_status    varchar2(30);
        l_new_status        varchar2(30);
        l_legal_norm        varchar2(50);
        l_now               date := cast(systimestamp at time zone 'Asia/Dubai' as date);
    begin
        ------------------------------------------------------------------
        -- Normalize legal status
        -- Supports both LEGAL_ABSCONDING and ABSCONDING
        ------------------------------------------------------------------
        l_legal_norm := p_legal_status;--replace(upper(nvl(p_legal_status, 'NOT_SET')), 'LEGAL_', '');

        ------------------------------------------------------------------
        -- Check active assignment
        ------------------------------------------------------------------
        BEGIN 
        select count(*)
          into l_active_assignment
          from hr_assignments
         where emp_id = p_emp_id
           and end_dt is null;
           EXCEPTION WHEN OTHERS THEN l_active_assignment:=0;
           END;

        ------------------------------------------------------------------
        -- Get current working status
        ------------------------------------------------------------------
        begin
            select status_code
              into l_current_status
              from (
                    select status_code
                      from hr_emp_status_hist
                     where emp_id = p_emp_id
                       and effective_to is null
                     order by effective_from desc, status_id desc
                   )
             where rownum = 1;
        exception
            when no_data_found then
                l_current_status := null;
        end;

        ------------------------------------------------------------------
        -- If employee still has active assignment, do not auto-change
        -- Legal status can still remain Absconding as risk badge.
        ------------------------------------------------------------------
        if l_active_assignment > 0 then
            return;
        end if;

        ------------------------------------------------------------------
        -- Decide new working status
        ------------------------------------------------------------------
        if l_legal_norm in ('ABSCONDING', 'ABSCONDER') then
            l_new_status := 'ABS';

        elsif l_legal_norm in ('CANCELLED', 'CANCELLED_MOHRE', 'CANCELLED_ICP') then
            l_new_status := 'INACTIVE';

        else
            return;
        end if;

        ------------------------------------------------------------------
        -- Avoid duplicate current status
        ------------------------------------------------------------------
        if upper(nvl(l_current_status, 'X')) = l_new_status then
            return;
        end if;

        ------------------------------------------------------------------
        -- Close current working status
        ------------------------------------------------------------------
        update hr_emp_status_hist
           set effective_to = l_now
         where emp_id = p_emp_id
           and effective_to is null;

        ------------------------------------------------------------------
        -- Insert new working status
        ------------------------------------------------------------------
        insert into hr_emp_status_hist (
            emp_id,
            status_code,
            effective_from,
            effective_to,
            remarks
        )
        values (
            p_emp_id,
            l_new_status,
            l_now,
            null,
            'Auto updated from legal status: ' || p_legal_status ||
            case
                when p_reason is not null then ' - ' || p_reason
                else null
            end
        );

    end sync_working_status;

end hr_legal_status_sync_pkg;
/
