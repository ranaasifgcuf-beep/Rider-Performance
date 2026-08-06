CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_INSURANCE_STATUS" ("EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "INSURANCE_TYPE", "INSURANCE_ID", "PROVIDER_NAME", "POLICY_NO", "MEMBER_CARD_NO", "PLAN_NAME", "CLASS_NAME", "ISSUE_DT", "START_DT", "EXPIRY_DT", "NEAR_EXPIRY_DAYS", "STATUS_CODE", "IS_CURRENT", "CANCEL_DT", "CANCEL_REASON", "CANCELLED_BY", "REMARKS", "INSURANCE_BUCKET", "DAYS_LEFT", "STATUS_BADGE_TEXT", "CURRENT_PROJECT") AS 
  with types as (
    select 'HEALTH' insurance_type from dual
    union all
    select 'WC' insurance_type from dual
),
picked as (
    select i.*,
           row_number() over (
               partition by i.emp_id, i.insurance_type
               order by case when i.is_current = 'Y' then 1 else 2 end,
                        nvl(i.start_dt, date '1900-01-01') desc,
                        i.insurance_id desc
           ) rn
    from hr_emp_insurance i
)
select e.emp_id,
       e.emp_code,
       e.full_employee_name as employee_name,
       t.insurance_type,
       p.insurance_id,
       p.provider_name,
       p.policy_no,
       p.member_card_no,
       p.plan_name,
       p.class_name,
       p.issue_dt,
       p.start_dt,
       p.expiry_dt,
       p.near_expiry_days,
       p.status_code,
       p.is_current,
       p.cancel_dt,
       p.cancel_reason,
       p.cancelled_by,
       p.remarks,
       case
           when p.insurance_id is null then 'PENDING'
           when p.status_code = 'CANCELLED' then 'CANCELLED'
           when p.expiry_dt is not null and p.expiry_dt < trunc(sysdate) then 'EXPIRED'
           when p.expiry_dt is not null
                and p.expiry_dt between trunc(sysdate) and trunc(sysdate) + nvl(p.near_expiry_days,30)
                then 'NEAR_EXPIRY'
           else 'VALID'
       end as insurance_bucket,
       case
           when p.expiry_dt is not null then p.expiry_dt - trunc(sysdate)
       end as days_left,
       e.STATUS_BADGE_TEXT,
       e.current_project
from VW_HR_EMPLOYEE_LIST e
cross join types t
left join picked p
       on p.emp_id = e.emp_id
      and p.insurance_type = t.insurance_type
      and p.rn = 1;
