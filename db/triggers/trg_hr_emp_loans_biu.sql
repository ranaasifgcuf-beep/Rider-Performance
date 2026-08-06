CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_EMP_LOANS_BIU" 
before insert or update on hr_emp_loans
for each row
declare
    l_year varchar2(4);
begin
    l_year := to_char(cast(systimestamp at time zone 'Asia/Dubai' as timestamp), 'YYYY');

    if inserting then
        if :new.loan_no is null then
            :new.loan_no := 'LOAN-' || l_year || '-' || lpad(hr_emp_loan_seq.nextval, 6, '0');
        end if;

        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
        :new.status := nvl(:new.status,'ACTIVE');
        :new.approval_status := nvl(:new.approval_status,'APPROVED');
    end if;

    if updating then
        :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_EMP_LOANS_BIU" ENABLE;
