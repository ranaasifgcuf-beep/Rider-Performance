CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_APPR_RULE_STEPS_BIU" 
before insert or update on hr_approval_rule_steps
for each row
begin
    -- Standardize approver type
    :new.approver_type := upper(trim(:new.approver_type));

    -- Standardize user / role values
    if :new.approver_user_name is not null then
        :new.approver_user_name := upper(trim(:new.approver_user_name));
    end if;

    if :new.approver_role_code is not null then
        :new.approver_role_code := upper(trim(:new.approver_role_code));
    end if;

    -- Clean opposite field
    if :new.approver_type = 'USER' then
        :new.approver_role_code := null;
    elsif :new.approver_type = 'ROLE' then
        :new.approver_user_name := null;
    end if;

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

ALTER TRIGGER "TRG_HR_APPR_RULE_STEPS_BIU" ENABLE;
