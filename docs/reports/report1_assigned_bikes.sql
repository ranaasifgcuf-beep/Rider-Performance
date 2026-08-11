select
  '<a href="' ||
  apex_page.get_url(
      p_page   => 100,
      p_items  => 'P100_EMP_ID',
      p_values => v.current_emp_id
  ) || '">' || v.employee_name || '</a>' as employee_name,

  v.emp_code,
  v.current_project as project_name,

  v.bike_code,
  v.plate_no,
  v.model_name,

  case
    when v.bike_status_code = 'AVAILABLE' then
      '<span class="t-Badge t-Badge--success">AVAILABLE</span>'
    when v.bike_status_code = 'ASSIGNED' then
      '<span class="t-Badge t-Badge--info">ASSIGNED</span>'
    when v.bike_status_code in ('ACCIDENT','MAINTENANCE') then
      '<span class="t-Badge t-Badge--warning">' || v.bike_status_name || '</span>'
    when v.bike_status_code in ('IMPOUND','POLICE_CUSTODY') then
      '<span class="t-Badge t-Badge--danger">' || v.bike_status_name || '</span>'
    else
      '<span class="t-Badge t-Badge--default">' || nvl(v.bike_status_name,'N/A') || '</span>'
  end as bike_status_badge,

  v.current_assign_dt as assign_dt,
  v.current_expected_return_dt as expected_return_dt,

  case
    when v.current_expected_return_dt is not null
     and v.current_expected_return_dt < sysdate then
      '<span class="t-Badge t-Badge--danger">OVERDUE</span>'
    when v.current_expected_return_dt is not null
     and v.current_expected_return_dt <= sysdate + 3 then
      '<span class="t-Badge t-Badge--warning">DUE SOON</span>'
    else
      '<span class="t-Badge t-Badge--success">ON TRACK</span>'
  end as return_status_badge,

  v.current_issue_condition as issue_condition

from vw_fleet_bike_current v
where v.current_emp_id is not null
order by v.current_project, v.employee_name;
