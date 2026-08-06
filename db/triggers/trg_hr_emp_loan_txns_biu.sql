CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_EMP_LOAN_TXNS_BIU" 
before insert or update on hr_emp_loan_txns
for each row
begin
    if inserting then
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

        if :new.txn_date is null then
            :new.txn_date := trunc(cast(systimestamp at time zone 'Asia/Dubai' as date));
        end if;

        :new.approval_status := nvl(:new.approval_status, 'DRAFT');
    end if;

    if updating then
        :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_EMP_LOAN_TXNS_BIU" ENABLE;
