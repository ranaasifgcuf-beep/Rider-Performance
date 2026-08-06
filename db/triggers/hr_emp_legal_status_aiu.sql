CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_LEGAL_STATUS_AIU" 
after insert or update of legal_status on hr_emp_legal_profile
for each row
declare
    l_old_legal_status   varchar2(30);
    l_effective_from_dt  date;
begin
    l_effective_from_dt := nvl(
                              :new.legal_status_dt,
                              cast(systimestamp at time zone 'Asia/Dubai' as date)
                          );

    if inserting then
        l_old_legal_status := null;
    else
        l_old_legal_status := :old.legal_status;
    end if;

    if inserting
       or nvl(:old.legal_status,'#') <> nvl(:new.legal_status,'#') then

        ------------------------------------------------------------------
        -- Close previous current status
        ------------------------------------------------------------------
        update hr_emp_legal_status_hist
           set effective_to_dt   = l_effective_from_dt,
               is_current_record = 'N'
         where legal_profile_id = :new.legal_profile_id
           and is_current_record = 'Y';

        ------------------------------------------------------------------
        -- Insert new current status
        ------------------------------------------------------------------
        insert into hr_emp_legal_status_hist (
            legal_profile_id,
            emp_id,
            old_legal_status,
            new_legal_status,
            legal_status_reason,
            legal_status_dt,
            effective_from_dt,
            effective_to_dt,
            is_current_record,
            legal_case_ref,
            remarks,
            created_by,
            created_dt
        )
        values (
            :new.legal_profile_id,
            :new.emp_id,
            l_old_legal_status,
            :new.legal_status,
            :new.legal_status_reason,
            l_effective_from_dt,
            l_effective_from_dt,
            null,
            'Y',
            :new.legal_case_ref,
            :new.legal_case_remarks,
            nvl(v('APP_USER'), user),
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
        );

    end if;
end;
/

ALTER TRIGGER "HR_EMP_LEGAL_STATUS_AIU" ENABLE;
