CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_EMPLOYEES_BIU" 
before insert or update on hr_employees
for each row
declare
l_next number;
begin
    if inserting then
         if :new.emp_id is null then
            :new.emp_id := hr_emp_seq.nextval;
        end if;

        if :new.emp_code is null then
            if :new.emp_code is null then
        select nvl(max(emp_code),0) + 1
        into l_next
        from hr_employees;
        
        :new.emp_code := l_next;
    end if;
        end if;

        :new.created_by :=v('APP_USER');
        :new.created_DT := nvl(:new.created_dt, cast(systimestamp at time zone 'Asia/Dubai' as date));

        :new.updated_by := v('APP_USER');
        :new.updated_DT := nvl(:new.created_dt, cast(systimestamp at time zone 'Asia/Dubai' as date));

    elsif updating then
        :new.updated_by := v('APP_USER');
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as date);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_EMPLOYEES_BIU" ENABLE;
