CREATE OR REPLACE EDITIONABLE TRIGGER "SEC_USERS_T" 
before
insert or update or delete on "SEC_USERS"
for each row
begin
    if inserting then
    :new.created_on := nvl(:new.created_on, cast(systimestamp at time zone 'Asia/Dubai' as date));
    :new.created_by     := nvl(:new.created_by, v('APP_USER'));
  end if;

  if updating then
    :new.updated_on := cast(systimestamp at time zone 'Asia/Dubai' as date);
    :new.updated_by     := v('APP_USER');
  end if;
end;
/

ALTER TRIGGER "SEC_USERS_T" ENABLE;
