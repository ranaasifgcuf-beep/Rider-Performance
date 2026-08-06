CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_CHARGE_INSTALLMENTS_BIU" 
before insert or update on hr_emp_charge_installments
for each row
begin
    if inserting then
        if :new.status_code is null then
            :new.status_code := 'PENDING';
        end if;

        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "HR_EMP_CHARGE_INSTALLMENTS_BIU" ENABLE;
