CREATE OR REPLACE EDITIONABLE TRIGGER "HR_EMP_LEGAL_PROFILE_BIU" 
before insert or update on hr_emp_legal_profile
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

        if :new.legal_status_dt is null then
            :new.legal_status_dt := (cast(systimestamp at time zone 'Asia/Dubai' as date));
        end if;

        if :new.wps_effective_from_dt is null then
            :new.wps_effective_from_dt := (cast(systimestamp at time zone 'Asia/Dubai' as date));
        end if;
    end if;

    if updating then
        :new.updated_by := nvl(v('APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

        if nvl(:old.legal_status,'#') <> nvl(:new.legal_status,'#') then
            :new.legal_status_dt := (cast(systimestamp at time zone 'Asia/Dubai' as date));
        end if;
    end if;

    ------------------------------------------------------------------
    -- WPS setup alignment
    ------------------------------------------------------------------
    if :new.default_wps_clearing_mode = 'NOT_REQUIRED' then
        :new.wps_required_yn := 'N';
        :new.wps_status      := 'NOT_REQUIRED';
    elsif :new.default_wps_clearing_mode = 'BLOCKED' then
        :new.wps_status := 'BLOCKED';
    elsif :new.default_wps_clearing_mode = 'MANAGEMENT_EXCEPTION' then
        :new.wps_status := 'EXCEPTION';
    else
        :new.wps_required_yn := 'Y';
    end if;

    ------------------------------------------------------------------
    -- Legal validation only when status is VALID
    ------------------------------------------------------------------
    if :new.legal_status = 'VALID'
       and :new.legal_worker_type in ('OWN_VISA','GROUP_COMPANY')
       and :new.legal_org_id is null then
        raise_application_error(-20001, 'Legal company is required.');
    end if;

    if :new.legal_status = 'VALID'
       and :new.legal_worker_type in ('FREELANCE','FAMILY_SPONSORED','GOLDEN_VISA','OTHER')
       and :new.external_sponsor_name is null then
        raise_application_error(-20002, 'External sponsor / sponsor reference is required.');
    end if;

    ------------------------------------------------------------------
    -- WPS validation only when WPS status is ACTIVE
    ------------------------------------------------------------------
    if :new.wps_status = 'ACTIVE'
       and :new.wps_required_yn = 'Y'
       and nvl(:new.wps_salary_amount,0) <= 0 then
        raise_application_error(-20101, 'WPS salary amount is required.');
    end if;
end;
/

ALTER TRIGGER "HR_EMP_LEGAL_PROFILE_BIU" ENABLE;
