CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_LEGAL_PROFILE_SYNC_STATUS" 
after insert or update of legal_status
on hr_emp_legal_profile
for each row
begin
    if inserting
       or nvl(:old.legal_status, 'X') <> nvl(:new.legal_status, 'X')
    then
        hr_legal_status_sync_pkg.sync_working_status(
            p_emp_id       => :new.emp_id,
            p_legal_status => :new.legal_status,
            p_reason       => :new.legal_status_reason
        );
    end if;
end;
/

ALTER TRIGGER "TRG_LEGAL_PROFILE_SYNC_STATUS" ENABLE;
