CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_CURRENT_SIMS" ("SIM_ASSIGN_ID", "EMP_ID", "EMP_CODE", "FULL_EMPLOYEE_NAME", "SIM_ID", "MOBILE_NO", "ICCID_NO", "OPERATOR_CODE", "OPERATOR_NAME", "OWNERSHIP_TYPE", "OWNER_SUPPLIER_ID", "OWNER_SUPPLIER_NAME", "EXTERNAL_OWNER_NAME", "EXTERNAL_OWNER_MOBILE", "PLAN_NAME", "DATA_PACKAGE", "MONTHLY_COST", "ASSIGN_DT", "ASSIGN_REASON", "ASSIGNED_BY", "ASSIGN_REMARKS", "SIM_DISPLAY", "SIM_BADGE") AS 
  select sa.sim_assign_id,
       sa.emp_id,
       e.emp_code,
       e.full_employee_name,

       sa.sim_id,
       s.mobile_no,
       s.iccid_no,
       s.operator_code,
       op.operator_name,

       s.ownership_type,
       s.owner_supplier_id,
       fs.supplier_name as owner_supplier_name,
       s.external_owner_name,
       s.external_owner_mobile,

       s.plan_name,
       s.data_package,
       s.monthly_cost,

       sa.assign_dt,
       sa.assign_reason,
       sa.assigned_by,
       sa.assign_remarks,

       s.mobile_no as sim_display,

       '<span class="t-Badge t-Badge--warning">' ||
       apex_escape.html(s.mobile_no) ||
       '</span>' as sim_badge

  from hr_sim_assignments sa
  join fleet_sims s
    on s.sim_id = sa.sim_id
  join fleet_sim_operators op
    on op.operator_code = s.operator_code
  join vw_hr_employee_list e
    on e.emp_id = sa.emp_id
  left join fin_suppliers fs
    on fs.supplier_id = s.owner_supplier_id
 where sa.return_dt is null;
