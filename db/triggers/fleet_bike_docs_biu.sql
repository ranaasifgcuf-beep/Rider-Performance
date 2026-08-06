CREATE OR REPLACE EDITIONABLE TRIGGER "FLEET_BIKE_DOCS_BIU" 
before insert or update on fleet_bike_docs
for each row
begin
    if inserting then
        if :new.is_current is null then
            :new.is_current := 'Y';
        end if;

        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "FLEET_BIKE_DOCS_BIU" ENABLE;
