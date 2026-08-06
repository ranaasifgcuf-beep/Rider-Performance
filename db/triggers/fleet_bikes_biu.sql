CREATE OR REPLACE EDITIONABLE TRIGGER "FLEET_BIKES_BIU" 
before insert or update on fleet_bikes
for each row
begin
    if inserting then
        if :new.is_active is null then
            :new.is_active := 'Y';
        end if;

        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "FLEET_BIKES_BIU" ENABLE;
