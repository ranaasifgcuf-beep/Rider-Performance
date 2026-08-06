CREATE OR REPLACE EDITIONABLE TRIGGER "FLEET_BIKE_CUSTODY_TXNS_BIU" 
before insert or update on fleet_bike_custody_txns
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

ALTER TRIGGER "FLEET_BIKE_CUSTODY_TXNS_BIU" ENABLE;
