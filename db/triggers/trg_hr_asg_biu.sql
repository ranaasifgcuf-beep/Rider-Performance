CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_ASG_BIU" 
before insert or update on hr_assignments
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

  if :new.end_dt is not null then
  :new.status := 'ENDED';
  end if;

  /*
  hr_asg_pkg.validate_assignment(
    p_asg_id   => :new.asg_id,
    p_emp_id   => :new.emp_id,
    p_start_dt => :new.start_dt,
    p_end_dt   => :new.end_dt
  );
  */
end;
/

ALTER TRIGGER "TRG_HR_ASG_BIU" ENABLE;
