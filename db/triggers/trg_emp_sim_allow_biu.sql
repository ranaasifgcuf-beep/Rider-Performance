CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_EMP_SIM_ALLOW_BIU" 
before insert or update on hr_emp_sim_allowances
for each row
declare
    l_user varchar2(100);
    l_now  date;
begin
    l_user := nvl(sys_context('APEX$SESSION','APP_USER'), user);
    l_now  := cast(systimestamp at time zone 'Asia/Dubai' as date);

    if inserting then
        :new.created_by      := nvl(:new.created_by, l_user);
        :new.created_dt      := nvl(:new.created_dt, l_now);
        :new.approved_by     := nvl(:new.approved_by, l_user);
        :new.approved_dt     := nvl(:new.approved_dt, l_now);
        :new.is_active       := nvl(:new.is_active, 'Y');
        :new.max_active_sims := nvl(:new.max_active_sims, 1);
        :new.effective_from  := nvl(:new.effective_from, trunc(l_now));
    end if;

    :new.updated_by := l_user;
    :new.updated_dt := l_now;

    :new.is_active := upper(trim(:new.is_active));
end;
/

ALTER TRIGGER "TRG_EMP_SIM_ALLOW_BIU" ENABLE;
