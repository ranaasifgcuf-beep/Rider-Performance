create or replace package body hr_legal_profile_pkg as

    procedure ensure_profile (
        p_emp_id in number
    ) is
    begin
        insert into hr_emp_legal_profile (
            emp_id,
            legal_worker_type,
            legal_org_id,
            legal_status,
            legal_status_reason,
            legal_status_dt,
            wps_required_yn,
            wps_status,
            default_wps_clearing_mode,
            wps_effective_from_dt,
            created_by,
            created_dt
        )
        select e.emp_id,
               case
                   when nvl(e.worker_type,'DIRECT') = 'SUBCONTRACT' then 'SUBCONTRACT'
                   else 'OWN_VISA'
               end as legal_worker_type,
               null as legal_org_id,
               'IN_PROCESS' as legal_status,
               'Initial legal profile created' as legal_status_reason,
               trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) as legal_status_dt,
               'Y' as wps_required_yn,
               'SETUP_PENDING' as wps_status,
               case
                   when nvl(e.worker_type,'DIRECT') = 'SUBCONTRACT' then 'SUPPLIER_WPS'
                   else 'INTERNAL_WPS'
               end as default_wps_clearing_mode,
               trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) as wps_effective_from_dt,
               nvl(v('APP_USER'), user) as created_by,
               cast(systimestamp at time zone 'Asia/Dubai' as timestamp) as created_dt
          from hr_employees e
         where e.emp_id = p_emp_id
           and not exists (
                select 1
                  from hr_emp_legal_profile lp
                 where lp.emp_id = e.emp_id
           );
    end ensure_profile;


    procedure ensure_all_profiles is
    begin
        for r in (
            select emp_id
              from hr_employees
        ) loop
            ensure_profile(r.emp_id);
        end loop;
    end ensure_all_profiles;

end hr_legal_profile_pkg;
/
