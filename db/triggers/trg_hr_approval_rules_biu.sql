CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_APPROVAL_RULES_BIU" 
before insert or update on hr_approval_rules
for each row
begin
    -- Standardize codes
    :new.module_code := upper(trim(:new.module_code));

    if :new.txn_type_code is not null then
        :new.txn_type_code := upper(trim(:new.txn_type_code));
    end if;

    -- Defaults
    :new.is_active := nvl(:new.is_active, 'Y');
    :new.min_amount := nvl(:new.min_amount, 0);
    :new.max_amount := nvl(:new.max_amount, 999999999);
    :new.seq_no := nvl(:new.seq_no, 10);

    if inserting then
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;

    if updating then
        -- protect original created info
        :new.created_by := :old.created_by;
        :new.created_dt := :old.created_dt;

        :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_APPROVAL_RULES_BIU" ENABLE;
