CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMPLOYEE_LIST" ("EMP_ID", "EMP_CODE", "FIRST_NAME", "LAST_NAME", "FATHER_NAME", "DOB", "FULL_EMPLOYEE_NAME", "EMP_INITIALS", "AGE", "NATIONALITY_COUNTRY_ID", "NATIONALITY", "MOBILE", "EMAIL", "JOIN_DATE", "AGREED_PROJECT_ID", "AGREED_PROJECT", "AGREED_CITY_ID", "AGREED_CITY", "JOB_ID", "JOB_NAME", "REFERENCE_SOURCE", "REFERRED_BY_TEXT", "DEAL_BY_USER", "DEAL_BY_USER_NAME", "HIRE_NOTES", "WORKER_TYPE", "SUPPLIER_ID", "SUPPLIER_NAME", "CONTRACT_REF", "HAS_PHOTO", "CURRENT_PROJECT_ID", "CURRENT_PROJECT", "CURRENT_CITY_ID", "CURRENT_CITY", "LAST_PROJECT_ID", "LAST_PROJECT", "LAST_CITY_ID", "LAST_CITY", "DISPLAY_CURRENT_PROJECT", "DISPLAY_CURRENT_CITY", "DISPLAY_LAST_PROJECT", "DISPLAY_LAST_CITY", "CURRENT_STATUS_CODE", "CURRENT_STATUS_NAME", "STATUS_DISPLAY_TEXT", "STATUS_BADGE_TEXT", "CUSTODY_BADGE", "PAY_MODE_NAME", "INSURANCE_BUCKET_BADGE", "INSURRANCE_BUCKET_TEXT", "WC_INS_BUCKET_BADGE", "WC_INS_BUCKET_TEXT", "PHOTO_BLOB", "CURRENT_LEGAL_CODE", "CURRENT_LEGAL_NAME", "STATUS_PROJECT_ID", "STATUS_PROJECT_NAME", "STATUS_CITY_ID", "STATUS_CITY_NAME") AS 
  with cur_asg as (
    select emp_id,
           project_id,
           city_id,
           job_id,
           start_dt,
           asg_id,
           row_number() over (
               partition by emp_id
               order by start_dt desc, asg_id desc
           ) as rn
      from hr_assignments
     where end_dt is null
),

last_asg as (
    select emp_id,
           project_id,
           city_id,
           job_id,
           start_dt,
           end_dt,
           asg_id,
           row_number() over (
               partition by emp_id
               order by end_dt desc, asg_id desc
           ) as rn
      from hr_assignments
     where end_dt is not null
),

cur_status as (
    select emp_id,
           status_code,
           effective_from,
           status_id,
           project_id,
           city_id,
           row_number() over (
               partition by emp_id
               order by effective_from desc, status_id desc
           ) as rn
      from hr_emp_status_hist
     where effective_to is null
),

curr_pp_status as (
    select emp_id,
           case current_status
               when 'WITH_COMPANY' then
                   '<span class="t-Badge t-Badge--success">With Company</span>'
               when 'WITH_EMPLOYEE' then
                   '<span class="t-Badge t-Badge--warning">With Rider</span>'
               else
                   '<span class="t-Badge t-Badge--danger">Pending</span>'
           end as custody_badge
      from vw_hr_doc_custody_current
),

curr_pay_method as (
    select a.emp_id,
           pm.pay_mode_name
      from hr_emp_pay_modes a
      join hr_pay_mode_master pm
        on pm.pay_mode_code = a.pay_mode_code
     where a.is_active = 'Y'
),

curr_health_ins as (
    select i.*,
           row_number() over (
               partition by i.emp_id, i.insurance_type
               order by case when i.is_current = 'Y' then 1 else 2 end,
                        nvl(i.start_dt, date '1900-01-01') desc,
                        i.insurance_id desc
           ) rn
      from hr_emp_insurance i
     where i.insurance_type = 'HEALTH'
),

curr_wc_ins as (
    select i.*,
           row_number() over (
               partition by i.emp_id, i.insurance_type
               order by case when i.is_current = 'Y' then 1 else 2 end,
                        nvl(i.start_dt, date '1900-01-01') desc,
                        i.insurance_id desc
           ) rn
      from hr_emp_insurance i
     where i.insurance_type = 'WC'
)

select e.emp_id,
       e.emp_code,
       e.first_name,
       e.last_name,
       e.father_name,
       e.dob,

       trim(
           nvl(e.first_name, '') ||
           case
               when e.last_name is not null then ' ' || e.last_name
           end
       ) as full_employee_name,

       upper(
           substr(nvl(e.first_name, 'X'), 1, 1) ||
           substr(nvl(e.last_name,  'X'), 1, 1)
       ) as emp_initials,

       case
           when e.dob is not null then
               trunc(months_between(trunc(sysdate), trunc(e.dob)) / 12)
       end as age,

       e.nationality_country_id,
       nc.country_name as nationality,

       e.mobile,
       e.email,
       e.join_date,

       e.agreed_project_id,
       ap.project_name as agreed_project,

       e.agreed_city_id,
       ac.city_name as agreed_city,

       e.job_id,
       j.job_name,

       e.reference_source,
       e.referred_by_text,
       e.deal_by_user,
       su.username as deal_by_user_name,
       e.hire_notes,

       e.worker_type,
       e.supplier_id,
       fs.supplier_name,
       e.contract_ref,

       case
           when e.photo_blob is not null then 'Y'
           else 'N'
       end as has_photo,

       ca.project_id as current_project_id,
       cp.project_name as current_project,

       ca.city_id as current_city_id,
       cc.city_name as current_city,

       la.project_id as last_project_id,
       lp.project_name as last_project,

       la.city_id as last_city_id,
       lc.city_name as last_city,

       nvl(cp.project_name, ap.project_name) as display_current_project,
       nvl(cc.city_name, ac.city_name)       as display_current_city,

       nvl(lp.project_name, nvl(cp.project_name, ap.project_name)) as display_last_project,
       nvl(lc.city_name,   nvl(cc.city_name, ac.city_name))        as display_last_city,

       ------------------------------------------------------------------
       -- Current Operational Status
       ------------------------------------------------------------------
       cs.status_code as current_status_code,

       nvl(sm.status_name, 'No Status') as current_status_name,

       nvl(sm.status_name, 'No Status') as status_display_text,

       case upper(cs.status_code)
           when 'ACTIVE' then
               '<span class="t-Badge t-Badge--success t-Badge--subtle">Active</span>'

           when 'READY_TO_ONBOARD' then
               '<span class="t-Badge t-Badge--warning t-Badge--subtle">Ready To Onboard</span>'

           when 'PIPELINE' then
               '<span class="t-Badge t-Badge--info t-Badge--subtle">Pipeline</span>'

           when 'IN_PROCESS' then
               '<span class="t-Badge t-Badge--warning t-Badge--subtle">In Process</span>'

           when 'ONBOARDING' then
               '<span class="t-Badge t-Badge--warning t-Badge--subtle">Onboarding</span>'

           when 'ON_HOLD' then
               '<span class="t-Badge t-Badge--danger t-Badge--subtle">On Hold</span>'

           when 'OFFBOARD' then
               '<span class="t-Badge t-Badge--warning">Offboard</span>'

           when 'OFFBOARD_QUEUE' then
               '<span class="t-Badge t-Badge--warning">Offboard Queue</span>'

           when 'VACATION' then
               '<span class="t-Badge t-Badge--info">Vacation</span>'

           when 'ACCIDENT' then
               '<span class="t-Badge t-Badge--danger">Accident</span>'

           when 'ABSCONDER' then
               '<span class="t-Badge t-Badge--danger">Absconder</span>'

           when 'ABS' then
               '<span class="t-Badge t-Badge--danger">Absconder</span>'

           when 'TERMINATED' then
               '<span class="t-Badge t-Badge--danger">Terminated</span>'

           when 'EXITED' then
               '<span class="t-Badge t-Badge--neutral t-Badge--subtle">Exited</span>'

           when 'INACTIVE' then
               '<span class="t-Badge t-Badge--neutral t-Badge--subtle">Inactive</span>'

           else
               '<span class="t-Badge t-Badge--info t-Badge--subtle">' ||
               apex_escape.html(nvl(sm.status_name, 'No Status')) ||
               '</span>'
       end as status_badge_text,

       cus_pp.custody_badge,
       pm.pay_mode_name,

       ------------------------------------------------------------------
       -- Health Insurance
       ------------------------------------------------------------------
       case
           when hins.insurance_id is null then
               '<span class="t-Badge t-Badge--info">PENDING</span>'
           when hins.status_code = 'CANCELLED' then
               '<span class="t-Badge t-Badge--danger t-Badge--outline"><span class="fa fa-ban"></span> CANCELLED</span>'
           when hins.expiry_dt is not null
                and hins.expiry_dt < trunc(sysdate) then
               '<span class="t-Badge t-Badge--danger">EXPIRED</span>'
           when hins.expiry_dt is not null
                and hins.expiry_dt between trunc(sysdate)
                                    and trunc(sysdate) + nvl(hins.near_expiry_days, 30) then
               '<span class="t-Badge t-Badge--warning">NEAR EXPIRY</span>'
           else
               '<span class="t-Badge t-Badge--success">VALID</span>'
       end as insurance_bucket_badge,

       case
           when hins.insurance_id is null then
               'PENDING'
           when hins.status_code = 'CANCELLED' then
               'CANCELLED'
           when hins.expiry_dt is not null
                and hins.expiry_dt < trunc(sysdate) then
               'EXPIRED'
           when hins.expiry_dt is not null
                and hins.expiry_dt between trunc(sysdate)
                                    and trunc(sysdate) + nvl(hins.near_expiry_days, 30) then
               'NEAR EXPIRY'
           else
               'VALID'
       end as insurrance_bucket_text,

       ------------------------------------------------------------------
       -- WC Insurance
       ------------------------------------------------------------------
       case
           when wins.insurance_id is null then
               '<span class="t-Badge t-Badge--info">PENDING</span>'
           when wins.status_code = 'CANCELLED' then
               '<span class="t-Badge t-Badge--danger t-Badge--outline"><span class="fa fa-ban"></span> CANCELLED</span>'
           when wins.expiry_dt is not null
                and wins.expiry_dt < trunc(sysdate) then
               '<span class="t-Badge t-Badge--danger">EXPIRED</span>'
           when wins.expiry_dt is not null
                and wins.expiry_dt between trunc(sysdate)
                                    and trunc(sysdate) + nvl(wins.near_expiry_days, 30) then
               '<span class="t-Badge t-Badge--warning">NEAR EXPIRY</span>'
           else
               '<span class="t-Badge t-Badge--success">VALID</span>'
       end as wc_ins_bucket_badge,

       case
           when wins.insurance_id is null then
               'PENDING'
           when wins.status_code = 'CANCELLED' then
               'CANCELLED'
           when wins.expiry_dt is not null
                and wins.expiry_dt < trunc(sysdate) then
               'EXPIRED'
           when wins.expiry_dt is not null
                and wins.expiry_dt between trunc(sysdate)
                                    and trunc(sysdate) + nvl(wins.near_expiry_days, 30) then
               'NEAR EXPIRY'
           else
               'VALID'
       end as wc_ins_bucket_text,

       e.photo_blob,

       ------------------------------------------------------------------
       -- Legal Status
       ------------------------------------------------------------------
       nvl(lg.legal_status, 'NOT_SET') as current_legal_code,

       nvl(lg.legal_status_name, 'Not Set') as current_legal_name,

       ------------------------------------------------------------------
       -- Status Project / City from HR_EMP_STATUS_HIST
       ------------------------------------------------------------------
       cs.project_id as status_project_id,
       sap.project_name as status_project_name,

       cs.city_id as status_city_id,
       sac.city_name as status_city_name

  from hr_employees e

  left join ref_countries nc
    on nc.country_id = e.nationality_country_id

  left join hr_projects ap
    on ap.project_id = e.agreed_project_id

  left join ref_cities ac
    on ac.city_id = e.agreed_city_id

  left join ref_jobs j
    on j.job_id = e.job_id

  left join fin_suppliers fs
    on fs.supplier_id = e.supplier_id

  left join cur_asg ca
    on ca.emp_id = e.emp_id
   and ca.rn = 1

  left join hr_projects cp
    on cp.project_id = ca.project_id

  left join ref_cities cc
    on cc.city_id = ca.city_id

  left join last_asg la
    on la.emp_id = e.emp_id
   and la.rn = 1

  left join hr_projects lp
    on lp.project_id = la.project_id

  left join ref_cities lc
    on lc.city_id = la.city_id

  left join cur_status cs
    on cs.emp_id = e.emp_id
   and cs.rn = 1

  left join hr_status_master sm
    on sm.status_code = cs.status_code
   and sm.status_nature = 'EMPLOYEE'

  left join hr_projects sap
    on sap.project_id = cs.project_id

  left join ref_cities sac
    on sac.city_id = cs.city_id

  left join hr_emp_legal_profile_v lg
    on lg.emp_id = e.emp_id

  left join curr_pp_status cus_pp
    on cus_pp.emp_id = e.emp_id

  left join curr_pay_method pm
    on pm.emp_id = e.emp_id

  left join curr_health_ins hins
    on hins.emp_id = e.emp_id
   and hins.rn = 1

  left join curr_wc_ins wins
    on wins.emp_id = e.emp_id
   and wins.rn = 1

  left join sec_users su
    on su.user_id = e.deal_by_user;
