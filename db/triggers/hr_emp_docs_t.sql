CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_DOCS_T" 
before insert or update on hr_emp_docs
for each row
begin
    if inserting then
        :new.created_by := nvl(v('APP_USER'), user);
        :new.created_dt := nvl(
            :new.created_dt,
            cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
        );

        :new.updated_by := nvl(v('APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;

    if updating then
        :new.updated_by := nvl(v('APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "HR_EMP_DOCS_T" ENABLE;
