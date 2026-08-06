CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_IDENTIFIERS_T" 
before
insert or update on "HR_EMP_IDENTIFIERS"
for each row
begin
    if inserting then
    :new.created_by := v('APP_USER');
    :new.created_dt := nvl(:new.created_dt, cast(systimestamp at time zone 'Asia/Dubai' as date));

    :new.updated_by := v('APP_USER');
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
  end if;

  if updating then
    :new.updated_by := v('APP_USER');
    :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
  end if;
end;
/

ALTER TRIGGER "HR_EMP_IDENTIFIERS_T" ENABLE;
