CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_DOC_CUSTODY_LOG_BIU" 
before insert or update on hr_doc_custody_log
for each row
begin
    if inserting then
        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "TRG_HR_DOC_CUSTODY_LOG_BIU" ENABLE;
