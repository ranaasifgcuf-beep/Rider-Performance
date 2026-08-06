CREATE OR REPLACE FORCE EDITIONABLE VIEW "HR_EMP_LOAN_V" ("LOAN_ID", "LOAN_NO", "EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "LOAN_TYPE", "LOAN_AMOUNT", "EMI_AMOUNT", "ISSUE_DT", "START_MONTH", "SOURCE_TYPE", "SOURCE_ID", "APPROVAL_STATUS", "STATUS", "REMARKS", "PAID_AMOUNT", "WAIVED_AMOUNT", "ADJUSTMENT_AMOUNT", "REVERSED_AMOUNT", "BAD_DEBT_AMOUNT", "BALANCE_AMOUNT", "CREATED_BY", "CREATED_DT", "UPDATED_BY", "UPDATED_DT", "AGREED_ADVANCE_AMOUNT") AS 
  select l.loan_id,
       l.loan_no,
       l.emp_id,
       e.emp_code,
       trim(e.first_name || ' ' || e.last_name) employee_name,

       l.loan_type,
       l.loan_amount,
       l.emi_amount,
       l.issue_dt,
       l.start_month,
       l.source_type,
       l.source_id,
       l.approval_status,
       l.status,
       l.remarks,

       nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type in ('PAYROLL_DEDUCTION','MANUAL_PAYMENT')
       ), 0) paid_amount,

       nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type = 'WAIVER'
       ), 0) waived_amount,

       nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type = 'ADJUSTMENT'
       ), 0) adjustment_amount,

       nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type = 'REVERSAL'
       ), 0) reversed_amount,

       nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type = 'BAD_DEBT_WRITE_OFF'
       ), 0) bad_debt_amount,

       l.loan_amount
       - nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type in (
                 'PAYROLL_DEDUCTION',
                 'MANUAL_PAYMENT',
                 'WAIVER',
                 'ADJUSTMENT',
                 'BAD_DEBT_WRITE_OFF'
             )
       ), 0)
       + nvl((
           select sum(t.amount)
           from hr_emp_loan_txns t
           where t.loan_id = l.loan_id
             and t.approval_status = 'APPROVED'
             and t.txn_type = 'REVERSAL'
       ), 0) balance_amount,

       l.created_by,
       l.created_dt,
       l.updated_by,
       l.updated_dt,
nvl(l.agreed_advance_amount,0) agreed_advance_amount
from hr_emp_loans l
join hr_employees e
  on e.emp_id = l.emp_id;
