CREATE OR REPLACE FORCE EDITIONABLE VIEW "HR_EMP_LEGAL_STATUS_HIST_V" ("LEGAL_STATUS_HIST_ID", "LEGAL_PROFILE_ID", "EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "OLD_LEGAL_STATUS", "NEW_LEGAL_STATUS", "LEGAL_STATUS_REASON", "LEGAL_STATUS_DT", "EFFECTIVE_FROM_DT", "EFFECTIVE_TO_DT", "IS_CURRENT_RECORD", "LEGAL_CASE_REF", "REMARKS", "CREATED_BY", "CREATED_DT") AS 
  select h.legal_status_hist_id,
       h.legal_profile_id,
       h.emp_id,
       e.emp_code,
       trim(e.first_name || ' ' || e.last_name) employee_name,

       h.old_legal_status,
       h.new_legal_status,

       h.legal_status_reason,
       h.legal_status_dt,

       h.effective_from_dt,
       h.effective_to_dt,
       h.is_current_record,

       h.legal_case_ref,
       h.remarks,
       h.created_by,
       h.created_dt
from hr_emp_legal_status_hist h
join hr_employees e
  on e.emp_id = h.emp_id;
