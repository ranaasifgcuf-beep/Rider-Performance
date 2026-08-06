CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_ORG_DOC_TYPE_BIU" 
before insert or update
on hr_org_doc_type_master
for each row
begin
    :new.doc_type_code := upper(trim(:new.doc_type_code));

    if inserting then
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

        if :new.is_active is null then
            :new.is_active := 'Y';
        end if;

        if :new.is_expirable is null then
            :new.is_expirable := 'Y';
        end if;
    end if;

    if updating then
        :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_ORG_DOC_TYPE_BIU" ENABLE;
