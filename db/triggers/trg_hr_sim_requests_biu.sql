CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_SIM_REQUESTS_BIU" 
before insert or update on hr_sim_requests
for each row
declare
    l_user varchar2(100);
    l_now  date;
begin
    l_user := nvl(sys_context('APEX$SESSION','APP_USER'), user);
    l_now  := cast(systimestamp at time zone 'Asia/Dubai' as date);

    if inserting then
        :new.created_by     := nvl(:new.created_by, l_user);
        :new.created_dt     := nvl(:new.created_dt, l_now);
        :new.requested_by   := nvl(:new.requested_by, l_user);
        :new.requested_dt   := nvl(:new.requested_dt, l_now);
        :new.request_status := nvl(:new.request_status, 'OPEN');
        :new.priority       := nvl(:new.priority, 'NORMAL');
    end if;

    :new.updated_by := l_user;
    :new.updated_dt := l_now;

    :new.request_type   := upper(trim(:new.request_type));
    :new.request_status := upper(trim(:new.request_status));
    :new.priority       := upper(trim(:new.priority));
    :new.reason_code    := upper(trim(:new.reason_code));
end;
/

ALTER TRIGGER "TRG_HR_SIM_REQUESTS_BIU" ENABLE;
