CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_SIM_ASSIGN_STATUS_AIU" 
after insert or update of return_dt, return_reason, return_condition
on hr_sim_assignments
for each row
declare
    l_new_status varchar2(30);
begin
    if inserting then

        if :new.return_dt is null then
            update fleet_sims
               set sim_status_code = 'ASSIGNED',
                   updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
                   updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as date)
             where sim_id = :new.sim_id;
        end if;

    elsif updating then

        if :old.return_dt is null
           and :new.return_dt is not null then

            l_new_status :=
                case
                    when :new.return_reason = 'LOST'
                      or :new.return_condition = 'LOST'
                    then 'LOST'

                    when :new.return_reason = 'DAMAGED'
                      or :new.return_condition = 'DAMAGED'
                    then 'DAMAGED'

                    when :new.return_reason = 'CANCELLED'
                      or :new.return_condition = 'CANCELLED'
                    then 'CANCELLED'

                    when :new.return_condition = 'BLOCKED'
                    then 'BLOCKED'

                    else 'AVAILABLE'
                end;

            update fleet_sims
               set sim_status_code = l_new_status,
                   updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
                   updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as date)
             where sim_id = :new.sim_id;

        end if;

    end if;
end;
/

ALTER TRIGGER "TRG_HR_SIM_ASSIGN_STATUS_AIU" ENABLE;
