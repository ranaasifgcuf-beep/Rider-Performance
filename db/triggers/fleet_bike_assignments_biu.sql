CREATE OR REPLACE EDITIONABLE TRIGGER "FLEET_BIKE_ASSIGNMENTS_BIU" 
before insert or update on fleet_bike_assignments
for each row
begin
    if inserting then
        if :new.status_code is null then
            :new.status_code := 'ACTIVE';
        end if;

        if :new.assigned_by is null then
            :new.assigned_by := nvl(v('APP_USER'), user);
        end if;

        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    if updating then
        if :new.return_dt is not null and :old.return_dt is null then
            :new.returned_by := nvl(v('APP_USER'), user);
            :new.status_code := 'RETURNED';
        end if;
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "FLEET_BIKE_ASSIGNMENTS_BIU" ENABLE;
