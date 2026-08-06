CREATE OR REPLACE FORCE EDITIONABLE VIEW "HR_EMP_DOCS_V" ("DOC_ID", "EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "DOC_TYPE", "DOC_TYPE_NAME", "DOC_GROUP", "IS_MANDATORY", "DOC_NO", "ISSUE_DT", "EXPIRY_DT", "IS_CURRENT_RECORD", "RELATED_ID_REC_ID", "FILE_REF", "FILE_NAME", "MIME_TYPE", "FILE_SIZE", "REMARKS", "EXPIRY_IN_DAYS", "EXPIRY_STATUS", "CREATED_BY", "CREATED_DT", "UPDATED_BY", "UPDATED_DT") AS 
  select d.doc_id,
       d.emp_id,
       e.emp_code,
       trim(e.first_name || ' ' || e.last_name) employee_name,

       d.doc_type,
       t.doc_type_name,
       t.doc_group,
       nvl(t.is_mandatory,'N') is_mandatory,

       d.doc_no,
       d.issue_dt,
       d.expiry_dt,
       d.is_current_record,
       d.related_id_rec_id,
       d.file_ref,
       d.file_name,
       d.mime_type,
       d.file_size,
       d.remarks,

       case
           when d.expiry_dt is null then null
           else trunc(d.expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end expiry_in_days,

       case
           when d.expiry_dt is null then 'NO_EXPIRY'
           when trunc(d.expiry_dt) < trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) then 'EXPIRED'
           when trunc(d.expiry_dt) <= trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) + 30 then 'EXPIRING_SOON'
           else 'VALID'
       end expiry_status,

       d.created_by,
       d.created_dt,
       d.updated_by,
       d.updated_dt
from hr_emp_docs d
join hr_employees e
  on e.emp_id = d.emp_id
left join hr_doc_type_master t
  on t.doc_type_code = d.doc_type;
