CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_CHARGES_BIU" 
before insert or update on hr_emp_charges
for each row
begin
    if inserting then
        if :new.recurrence_type is null then
            :new.recurrence_type := 'ONE_TIME';
        end if;

        if :new.charge_to_employee_yn is null then
            :new.charge_to_employee_yn := 'Y';
        end if;

        if :new.excluded_from_charge_yn is null then
            :new.excluded_from_charge_yn := 'N';
        end if;

        if :new.approval_status is null then
            :new.approval_status := 'APPROVED';
        end if;

        if :new.payroll_processed_yn is null then
            :new.payroll_processed_yn := 'N';
        end if;

        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "HR_EMP_CHARGES_BIU" ENABLE;
