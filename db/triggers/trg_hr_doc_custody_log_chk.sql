CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_DOC_CUSTODY_LOG_CHK" 
before insert or update on hr_doc_custody_log
for each row
begin
    if :new.txn_type = 'RECEIVE_FROM_EMPLOYEE' then
        :new.external_status := 'WITH_COMPANY';
        :new.holder_type     := 'COMPANY_DEPT';

        if :new.holder_dept is null then
            :new.holder_dept := 'HR FILE';
        end if;
    elsif :new.txn_type = 'ISSUE_TO_EMPLOYEE' then
        :new.external_status := 'WITH_EMPLOYEE';
        :new.holder_type     := 'EMPLOYEE';
        :new.holder_user     := null;
        :new.holder_dept     := null;
    elsif :new.txn_type = 'INTERNAL_TRANSFER' then
        :new.external_status := 'WITH_COMPANY';

        if :new.holder_type not in ('COMPANY_USER','COMPANY_DEPT') then
            raise_application_error(-20001, 'Internal transfer must be to a company user or company department.');
        end if;
    end if;

    if :new.holder_type = 'COMPANY_USER' and :new.holder_user is null then
        raise_application_error(-20002, 'Holder user is required when holder type is COMPANY_USER.');
    end if;

    if :new.holder_type = 'COMPANY_DEPT' and :new.holder_dept is null then
        raise_application_error(-20003, 'Holder department is required when holder type is COMPANY_DEPT.');
    end if;

    if :new.holder_type = 'EMPLOYEE' then
        :new.holder_user := null;
        :new.holder_dept := null;
    end if;
end;
/

ALTER TRIGGER "TRG_HR_DOC_CUSTODY_LOG_CHK" ENABLE;
