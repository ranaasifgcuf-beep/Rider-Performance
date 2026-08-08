CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_FLEET_SIM_INVENTORY" ("SIM_ID", "MOBILE_NO", "ICCID_NO", "OPERATOR_CODE", "OPERATOR_NAME", "SIM_STATUS_CODE", "SIM_STATUS_NAME", "SIM_STATUS_BADGE", "OWNERSHIP_TYPE", "OWNER_NAME", "OWNER_SUPPLIER_ID", "EXTERNAL_OWNER_NAME", "EXTERNAL_OWNER_MOBILE", "EXTERNAL_OWNER_REF", "PLAN_NAME", "DATA_PACKAGE", "MONTHLY_COST", "BILL_ACCOUNT_NO", "CONTRACT_NO", "BILLING_REMARKS", "ACTIVATION_DT", "CANCELLATION_DT", "REMARKS", "CURRENT_EMP_ID", "CURRENT_EMP_CODE", "CURRENT_EMPLOYEE_NAME", "CURRENT_ASSIGN_DT", "CURRENT_HOLDER_BADGE") AS 
  select s.sim_id,
       s.mobile_no,
       s.iccid_no,

       s.operator_code,
       op.operator_name,

       s.sim_status_code,
       sm.sim_status_name,

       '<span class="t-Badge ' || sm.badge_class || '">' ||
       apex_escape.html(sm.sim_status_name) ||
       '</span>' as sim_status_badge,

       s.ownership_type,

       case
           when s.ownership_type = 'SUPPLIER' then
               fs.supplier_name
           when s.ownership_type in ('CLIENT','THIRD_PARTY','OTHER','RENTAL') then
               s.external_owner_name
           when s.ownership_type = 'EMPLOYEE' then
               'Employee Own'
           else
               'Company'
       end as owner_name,

       s.owner_supplier_id,
       s.external_owner_name,
       s.external_owner_mobile,
       s.external_owner_ref,

       s.plan_name,
       s.data_package,
       s.monthly_cost,
       s.bill_account_no,
       s.contract_no,
       s.billing_remarks,

       s.activation_dt,
       s.cancellation_dt,
       s.remarks,

       cs.emp_id as current_emp_id,
       cs.emp_code as current_emp_code,
       cs.full_employee_name as current_employee_name,
       cs.assign_dt as current_assign_dt,

       case
           when cs.emp_id is not null then
               '<span class="t-Badge t-Badge--warning">' ||
               apex_escape.html(cs.emp_code || ' - ' || cs.full_employee_name) ||
               '</span>'
           else
               '<span class="t-Badge t-Badge--success">Available</span>'
       end as current_holder_badge

  from fleet_sims s
  join fleet_sim_operators op
    on op.operator_code = s.operator_code
  join fleet_sim_status_master sm
    on sm.sim_status_code = s.sim_status_code
  left join fin_suppliers fs
    on fs.supplier_id = s.owner_supplier_id
  left join vw_hr_emp_current_sims cs
    on cs.sim_id = s.sim_id;
