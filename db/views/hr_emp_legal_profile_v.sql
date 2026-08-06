CREATE OR REPLACE FORCE EDITIONABLE VIEW "HR_EMP_LEGAL_PROFILE_V" ("LEGAL_PROFILE_ID", "EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "EMPLOYEE_WORKER_TYPE", "EMPLOYEE_SUPPLIER_ID", "SUPPLIER_NAME", "LEGAL_WORKER_TYPE", "LEGAL_ORG_ID", "LEGAL_ORG_NAME", "EXTERNAL_SPONSOR_NAME", "EXTERNAL_SPONSOR_REF", "LEGAL_PARTY_NAME", "LEGAL_STATUS", "LEGAL_STATUS_NAME", "LEGAL_STATUS_NATURE", "LEGAL_STATUS_BADGE_CLASS", "LEGAL_STATUS_SEQ_NO", "LEGAL_STATUS_REASON", "LEGAL_STATUS_DT", "LEGAL_CASE_REF", "LEGAL_CASE_REMARKS", "PASSPORT_NO", "PASSPORT_ISSUE_DT", "PASSPORT_EXPIRY_DT", "EMIRATES_ID_NO", "EMIRATES_ID_ISSUE_DT", "EMIRATES_ID_EXPIRY_DT", "VISA_NO", "VISA_ISSUE_DT", "VISA_EXPIRY_DT", "LABOUR_CARD_NO", "LABOUR_CARD_ISSUE_DT", "LABOUR_CARD_EXPIRY_DT", "LABOUR_CONTRACT_NO", "LABOUR_CONTRACT_DT", "WORK_PERMIT_NO", "WORK_PERMIT_ISSUE_DT", "WORK_PERMIT_EXPIRY_DT", "PASSPORT_EXPIRY_DAYS", "EID_EXPIRY_DAYS", "VISA_EXPIRY_DAYS", "LABOUR_CARD_EXPIRY_DAYS", "WPS_REQUIRED_YN", "WPS_STATUS", "DEFAULT_WPS_CLEARING_MODE", "WPS_CONTRACT_SALARY", "WPS_SALARY_AMOUNT", "WPS_EFFECTIVE_FROM_DT", "WPS_REMARKS", "WPS_CLEARING_DISPLAY", "REMARKS", "CREATED_BY", "CREATED_DT", "UPDATED_BY", "UPDATED_DT") AS 
  with docs as (
    select emp_id,

           max(case when doc_type = 'PASSPORT' then doc_no end) passport_no,
           max(case when doc_type = 'PASSPORT' then issue_dt end) passport_issue_dt,
           max(case when doc_type = 'PASSPORT' then expiry_dt end) passport_expiry_dt,

           max(case when doc_type = 'EMIRATES_ID' then doc_no end) emirates_id_no,
           max(case when doc_type = 'EMIRATES_ID' then issue_dt end) emirates_id_issue_dt,
           max(case when doc_type = 'EMIRATES_ID' then expiry_dt end) emirates_id_expiry_dt,

           max(case when doc_type = 'VISA_PAGE' then doc_no end) visa_no,
           max(case when doc_type = 'VISA_PAGE' then issue_dt end) visa_issue_dt,
           max(case when doc_type = 'VISA_PAGE' then expiry_dt end) visa_expiry_dt,

           max(case when doc_type = 'LABOUR_CARD' then doc_no end) labour_card_no,
           max(case when doc_type = 'LABOUR_CARD' then issue_dt end) labour_card_issue_dt,
           max(case when doc_type = 'LABOUR_CARD' then expiry_dt end) labour_card_expiry_dt,

           max(case when doc_type = 'LABOUR_CONTRACT' then doc_no end) labour_contract_no,
           max(case when doc_type = 'LABOUR_CONTRACT' then issue_dt end) labour_contract_dt,

           max(case when doc_type = 'WORK_PERMIT' then doc_no end) work_permit_no,
           max(case when doc_type = 'WORK_PERMIT' then issue_dt end) work_permit_issue_dt,
           max(case when doc_type = 'WORK_PERMIT' then expiry_dt end) work_permit_expiry_dt
      from hr_emp_docs
     where is_current_record = 'Y'
     group by emp_id
)
select lp.legal_profile_id,
       lp.emp_id,
       e.emp_code,
       trim(e.first_name || ' ' || e.last_name) employee_name,

       e.worker_type employee_worker_type,
       e.supplier_id employee_supplier_id,
       fs.supplier_name,

       lp.legal_worker_type,
       lp.legal_org_id,
       lo.org_name legal_org_name,

       lp.external_sponsor_name,
       lp.external_sponsor_ref,

       case
           when lp.legal_worker_type in ('OWN_VISA','GROUP_COMPANY') then lo.org_name
           when lp.legal_worker_type = 'SUBCONTRACT' then fs.supplier_name
           when lp.legal_worker_type in ('FREELANCE','FAMILY_SPONSORED','GOLDEN_VISA','OTHER') then lp.external_sponsor_name
           else null
       end legal_party_name,

       lp.legal_status,

       nvl(
           sm.status_name,
           replace(
               initcap(
                   lower(
                       replace(lp.legal_status, 'LEGAL_', '')
                   )
               ),
               '_',
               ' '
           )
       ) legal_status_name,

       sm.status_nature legal_status_nature,
       sm.badge_class legal_status_badge_class,
       sm.seq_no legal_status_seq_no,

       lp.legal_status_reason,
       lp.legal_status_dt,
       lp.legal_case_ref,
       lp.legal_case_remarks,

       d.passport_no,
       d.passport_issue_dt,
       d.passport_expiry_dt,

       d.emirates_id_no,
       d.emirates_id_issue_dt,
       d.emirates_id_expiry_dt,

       d.visa_no,
       d.visa_issue_dt,
       d.visa_expiry_dt,

       d.labour_card_no,
       d.labour_card_issue_dt,
       d.labour_card_expiry_dt,

       d.labour_contract_no,
       d.labour_contract_dt,

       d.work_permit_no,
       d.work_permit_issue_dt,
       d.work_permit_expiry_dt,

       case
           when d.passport_expiry_dt is null then null
           else trunc(d.passport_expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end passport_expiry_days,

       case
           when d.emirates_id_expiry_dt is null then null
           else trunc(d.emirates_id_expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end eid_expiry_days,

       case
           when d.visa_expiry_dt is null then null
           else trunc(d.visa_expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end visa_expiry_days,

       case
           when d.labour_card_expiry_dt is null then null
           else trunc(d.labour_card_expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end labour_card_expiry_days,

       lp.wps_required_yn,
       lp.wps_status,
       lp.default_wps_clearing_mode,
       lp.wps_contract_salary,
       lp.wps_salary_amount,
       lp.wps_effective_from_dt,
       lp.wps_remarks,

       case
           when lp.default_wps_clearing_mode = 'INTERNAL_WPS' then 'WPS inside company'
           when lp.default_wps_clearing_mode = 'OUTSIDE_CLEARING' then 'WPS outside clearing'
           when lp.default_wps_clearing_mode = 'SUPPLIER_WPS' then 'Supplier WPS'
           when lp.default_wps_clearing_mode = 'NOT_REQUIRED' then 'WPS not required'
           when lp.default_wps_clearing_mode = 'BLOCKED' then 'WPS blocked'
           when lp.default_wps_clearing_mode = 'MANAGEMENT_EXCEPTION' then 'Management exception'
           else lp.default_wps_clearing_mode
       end wps_clearing_display,

       lp.remarks,
       lp.created_by,
       lp.created_dt,
       lp.updated_by,
       lp.updated_dt
from hr_emp_legal_profile lp
join hr_employees e
  on e.emp_id = lp.emp_id
left join docs d
  on d.emp_id = lp.emp_id
left join hr_orgs lo
  on lo.org_id = lp.legal_org_id
left join fin_suppliers fs
  on fs.supplier_id = e.supplier_id
left join hr_status_master sm
  on sm.status_code =
        case
            when lp.legal_status like 'LEGAL_%' then lp.legal_status
            else 'LEGAL_' || lp.legal_status
        end
 and sm.status_nature = 'LEGAL';
