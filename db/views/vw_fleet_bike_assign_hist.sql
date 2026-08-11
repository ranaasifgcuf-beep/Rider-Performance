CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_FLEET_BIKE_ASSIGN_HIST" ("BIKE_ASSIGN_ID", "BIKE_ID", "BIKE_CODE", "PLATE_NO", "EMP_ID", "EMP_CODE", "EMPLOYEE_NAME", "CURRENT_PROJECT", "ASSIGN_DT", "EXPECTED_RETURN_DT", "RETURN_DT", "STATUS_CODE", "ISSUE_CONDITION", "RETURN_CONDITION", "RETURN_REASON_CODE", "ASSIGNED_BY", "RETURNED_BY", "REMARKS") AS
select fba.bike_assign_id,
       fba.bike_id,
       fb.bike_code,
       fb.plate_no,

       fba.emp_id,
       e.emp_code,
       e.full_employee_name as employee_name,
       e.current_project,

       fba.assign_dt,
       fba.expected_return_dt,
       fba.return_dt,
       fba.status_code,
       fba.issue_condition,
       fba.return_condition,
       fba.return_reason_code,
       fba.assigned_by,
       fba.returned_by,
       fba.remarks

  from fleet_bike_assignments fba
  join fleet_bikes fb
    on fb.bike_id = fba.bike_id
  join vw_hr_employee_list e
    on e.emp_id = fba.emp_id;
