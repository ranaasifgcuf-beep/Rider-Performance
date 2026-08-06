CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_DOC_CUSTODY_CURRENT" ("EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "LOG_ID", "DOC_TYPE", "TXN_TYPE", "TXN_DT", "EXTERNAL_STATUS", "HOLDER_TYPE", "HOLDER_USER", "HOLDER_DEPT", "RECEIVED_FROM", "ISSUED_TO", "PURPOSE", "EXPECTED_RETURN_DT", "REMARKS", "HANDLED_BY", "CURRENT_STATUS") AS 
  with latest_log as (
    select l.*,
           row_number() over (
               partition by l.emp_id, l.doc_type
               order by l.txn_dt desc, l.log_id desc
           ) rn
    from hr_doc_custody_log l
    where l.doc_type = 'PASSPORT'
)
select e.emp_id,
       e.emp_code,
       trim(e.first_name || ' ' || nvl(e.last_name,'')) as employee_name,
       ll.log_id,
       ll.doc_type,
       ll.txn_type,
       ll.txn_dt,
       ll.external_status,
       ll.holder_type,
       ll.holder_user,
       ll.holder_dept,
       ll.received_from,
       ll.issued_to,
       ll.purpose,
       ll.expected_return_dt,
       ll.remarks,
       ll.handled_by,
       case
           when ll.emp_id is null then 'PENDING'
           else ll.external_status
       end as current_status
from hr_employees e
left join latest_log ll
       on ll.emp_id = e.emp_id
      and ll.rn = 1;
