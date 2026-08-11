select
  '<a href="' ||
  apex_page.get_url(
      p_page   => 100,
      p_items  => 'P100_EMP_ID',
      p_values => h.emp_id
  ) || '">' || h.employee_name || '</a>' as employee_name,

  h.emp_code,
  h.current_project as project_name,

  h.bike_code,
  h.plate_no,

  case
    when h.status_code = 'ACTIVE' then
      '<span class="t-Badge t-Badge--info">ACTIVE</span>'
    when h.status_code = 'RETURNED' then
      '<span class="t-Badge t-Badge--success">RETURNED</span>'
    else
      '<span class="t-Badge t-Badge--default">' || h.status_code || '</span>'
  end as status_badge,

  h.assign_dt,
  h.expected_return_dt,
  h.return_dt,

  case
    when h.status_code = 'ACTIVE'
     and h.expected_return_dt is not null
     and h.expected_return_dt < sysdate then
      '<span class="t-Badge t-Badge--danger">OVERDUE</span>'
    else
      null
  end as overdue_flag,

  round(
    nvl(h.return_dt, sysdate) - h.assign_dt
  ) as days_held,

  h.issue_condition,
  h.return_condition,
  h.return_reason_code,
  h.assigned_by,
  h.returned_by,
  h.remarks

from vw_fleet_bike_assign_hist h
where (:P_EMP_CODE is null or upper(h.emp_code) = upper(:P_EMP_CODE))
  and (:P_BIKE_CODE is null
       or upper(h.bike_code) = upper(:P_BIKE_CODE)
       or upper(h.plate_no) = upper(:P_BIKE_CODE))
order by h.assign_dt desc;
