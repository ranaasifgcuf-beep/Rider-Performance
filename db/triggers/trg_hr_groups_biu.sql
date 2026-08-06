CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_GROUPS_BIU" 
before insert or update
on hr_groups
for each row
begin

    -- INSERT
    if inserting then

        :new.created_by :=
            nvl(
                sys_context('APEX$SESSION','APP_USER'),
                user
            );

        :new.created_dt :=
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

        -- default active
        if :new.is_active is null then
            :new.is_active := 'Y';
        end if;

    end if;


    -- UPDATE
    if updating then

        :new.updated_by :=
            nvl(
                sys_context('APEX$SESSION','APP_USER'),
                user
            );

        :new.updated_dt :=
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

    end if;

end;
/

ALTER TRIGGER "TRG_HR_GROUPS_BIU" ENABLE;
