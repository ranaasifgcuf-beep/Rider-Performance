CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_FLEET_SIMS_BIU" 
before insert or update on fleet_sims
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
        :new.sim_status_code := nvl(:new.sim_status_code, 'AVAILABLE');
        :new.ownership_type  := nvl(:new.ownership_type, 'COMPANY');
    end if;

    :new.updated_by := l_user;
    :new.updated_dt := l_now;

    :new.mobile_no       := trim(:new.mobile_no);
    :new.iccid_no        := trim(:new.iccid_no);
    :new.operator_code   := upper(trim(:new.operator_code));
    :new.sim_status_code := upper(trim(:new.sim_status_code));
    :new.ownership_type  := upper(trim(:new.ownership_type));
end;
/

ALTER TRIGGER "TRG_FLEET_SIMS_BIU" ENABLE;
