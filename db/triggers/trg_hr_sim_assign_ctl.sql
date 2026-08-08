CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_SIM_ASSIGN_CTL" 
for insert or update on hr_sim_assignments
compound trigger

    type t_emp_tab is table of number index by pls_integer;
    g_emp_ids t_emp_tab;
    g_idx     pls_integer := 0;

    function app_user return varchar2 is
    begin
        return nvl(sys_context('APEX$SESSION','APP_USER'), user);
    end;

    function uae_now return date is
    begin
        return cast(systimestamp at time zone 'Asia/Dubai' as date);
    end;

    procedure add_emp(p_emp_id number) is
    begin
        if p_emp_id is not null then
            g_idx := g_idx + 1;
            g_emp_ids(g_idx) := p_emp_id;
        end if;
    end;

before each row is
    l_sim_status varchar2(30);
begin
    if inserting then
        :new.created_by    := nvl(:new.created_by, app_user);
        :new.created_dt    := nvl(:new.created_dt, uae_now);
        :new.assigned_by   := nvl(:new.assigned_by, app_user);
        :new.assign_dt     := nvl(:new.assign_dt, uae_now);
        :new.assign_reason := nvl(:new.assign_reason, 'NEW_ISSUE');
    end if;

    if updating then
        if :old.return_dt is null
           and :new.return_dt is not null
           and :new.return_by is null then
            :new.return_by := app_user;
        end if;
    end if;

    :new.updated_by := app_user;
    :new.updated_dt := uae_now;

    :new.assign_reason    := upper(trim(:new.assign_reason));
    :new.return_reason    := upper(trim(:new.return_reason));
    :new.return_condition := upper(trim(:new.return_condition));

    ------------------------------------------------------------------
    -- Check SIM availability only when creating active assignment
    ------------------------------------------------------------------
    if :new.return_dt is null then

        if inserting then
            select sim_status_code
              into l_sim_status
              from fleet_sims
             where sim_id = :new.sim_id
             for update;

            if l_sim_status <> 'AVAILABLE' then
                raise_application_error(
                    -20001,
                    'SIM is not available for assignment.'
                );
            end if;
        end if;

        add_emp(:new.emp_id);
    end if;

    if updating then
        add_emp(:old.emp_id);
        add_emp(:new.emp_id);
    end if;
end before each row;

after statement is
    l_allowed_sims number;
    l_active_sims  number;
begin
    for i in 1 .. g_idx loop

        l_allowed_sims := 1;

        begin
            select max_active_sims
              into l_allowed_sims
              from (
                    select max_active_sims
                      from hr_emp_sim_allowances
                     where emp_id = g_emp_ids(i)
                       and is_active = 'Y'
                       and trunc(sysdate) between trunc(effective_from)
                                           and nvl(trunc(effective_to), date '4712-12-31')
                     order by effective_from desc, allowance_id desc
                   )
             where rownum = 1;
        exception
            when no_data_found then
                l_allowed_sims := 1;
        end;

        select count(*)
          into l_active_sims
          from hr_sim_assignments
         where emp_id = g_emp_ids(i)
           and return_dt is null;

        if l_active_sims > l_allowed_sims then
            raise_application_error(
                -20001,
                'Employee is allowed only ' || l_allowed_sims ||
                ' active SIM(s). Please add management SIM allowance before assigning additional SIM.'
            );
        end if;

    end loop;
end after statement;

end trg_hr_sim_assign_ctl;
/

ALTER TRIGGER "TRG_HR_SIM_ASSIGN_CTL" ENABLE;
