CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_EMP_INSURANCE_CHK" 
before insert or update on hr_emp_insurance
for each row
begin
    if :new.status_code = 'CANCELLED' then
        if :new.cancel_dt is null then
            :new.cancel_dt := trunc(sysdate);
        end if;

        if :new.cancel_reason is null then
            raise_application_error(-20011, 'Cancel reason is required for cancelled insurance.');
        end if;

        if :new.cancelled_by is null then
            :new.cancelled_by := nvl(v('APP_USER'), user);
        end if;
    else
        :new.cancel_dt     := null;
        :new.cancel_reason := null;
        :new.cancelled_by  := null;
    end if;

    if :new.expiry_dt is not null and :new.start_dt is not null and :new.expiry_dt < :new.start_dt then
        raise_application_error(-20012, 'Expiry date cannot be earlier than start date.');
    end if;

    if :new.near_expiry_days is null or :new.near_expiry_days <= 0 then
        :new.near_expiry_days := 30;
    end if;
end;
/

ALTER TRIGGER "TRG_HR_EMP_INSURANCE_CHK" ENABLE;
