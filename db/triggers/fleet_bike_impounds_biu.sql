CREATE OR REPLACE EDITIONABLE TRIGGER "FLEET_BIKE_IMPOUNDS_BIU" 
before insert or update on fleet_bike_impounds
for each row
begin
    if inserting then
        :new.charge_to_employee_yn := nvl(:new.charge_to_employee_yn, 'N');
        :new.excluded_from_charge_yn := nvl(:new.excluded_from_charge_yn, 'N');
        :new.status_code := nvl(:new.status_code, 'ACTIVE');
        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;

    :new.updated_by := nvl(v('APP_USER'), user);
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
end;
/

ALTER TRIGGER "FLEET_BIKE_IMPOUNDS_BIU" ENABLE;
