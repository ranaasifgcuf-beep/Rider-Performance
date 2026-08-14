with assignment_project as (
    select x.bike_assign_id,
           x.project_id,
           x.city_id
      from (
            select ba.bike_assign_id,
                   ha.project_id,
                   ha.city_id,
                   row_number() over (
                       partition by ba.bike_assign_id
                       order by ha.start_dt desc, ha.asg_id desc
                   ) rn
              from fleet_bike_assignments ba
              left join hr_assignments ha
                on ha.emp_id = ba.emp_id
               and ba.assign_dt >= ha.start_dt
               and ba.assign_dt < nvl(ha.end_dt, date '2999-12-31')
           ) x
     where x.rn = 1
)
select ba.bike_assign_id,
       ba.bike_id,

       ------------------------------------------------------------------
       -- Vehicle Detail
       ------------------------------------------------------------------
       b.bike_code,
       b.plate_no,
       b.plate_emirate,
       nvl(b.bike_code, b.plate_no) as vehicle_no,

       vc.model_name,
       vc.model_year_label,
       vc.color_name,
       vc.ownership_type,
       vc.vendor_name,

       ------------------------------------------------------------------
       -- Employee Detail
       ------------------------------------------------------------------
       ba.emp_id,
       e.emp_code,

       '<a href="' ||
       apex_page.get_url(
           p_page   => 100,
           p_items  => 'P100_EMP_ID',
           p_values => e.emp_id
       ) || '">' || e.full_employee_name || '</a>' as employee_name,

       e.job_name,
       e.worker_type,
       e.supplier_name,
       e.current_status_name,
       e.current_legal_name,

       ------------------------------------------------------------------
       -- Project / City at Assignment Time
       ------------------------------------------------------------------
       p.project_name,
       c.city_name,

       ------------------------------------------------------------------
       -- Assignment Dates
       ------------------------------------------------------------------
       to_char(ba.assign_dt, 'DD-MON-YYYY HH24:MI') as assign_dt,
       to_char(ba.expected_return_dt, 'DD-MON-YYYY') as expected_return_dt,
       to_char(ba.return_dt, 'DD-MON-YYYY HH24:MI') as return_dt,

       case
           when ba.return_dt is null then
               trunc(sysdate) - trunc(ba.assign_dt)
           else
               trunc(ba.return_dt) - trunc(ba.assign_dt)
       end as custody_days,

       ------------------------------------------------------------------
       -- Assignment Status
       ------------------------------------------------------------------
       case
           when ba.return_dt is null
            and upper(nvl(ba.status_code, 'ACTIVE')) = 'ACTIVE' then
               '<span class="t-Badge t-Badge--success">Currently Assigned</span>'

           when ba.return_dt is not null then
               '<span class="t-Badge t-Badge--normal">Returned</span>'

           else
               '<span class="t-Badge t-Badge--warning">' ||
               apex_escape.html(initcap(replace(ba.status_code, '_', ' '))) ||
               '</span>'
       end as assignment_status_badge,

       ba.status_code,
       ba.issue_condition,
       ba.return_condition,
       ba.remarks,

       ------------------------------------------------------------------
       -- Current Vehicle Position Now
       ------------------------------------------------------------------
       vc.bike_status_name      as current_vehicle_status,
       vc.custody_type_name     as current_custody_type,
       vc.custody_location_name as current_custody_location,

       case
           when vc.current_emp_id = ba.emp_id
            and ba.return_dt is null then
               '<span class="t-Badge t-Badge--success">Current Holder</span>'

           when vc.current_emp_id is not null
            and vc.current_emp_id <> ba.emp_id then
               '<span class="t-Badge t-Badge--warning">Now With Another Employee</span>'

           when vc.current_emp_id is null then
               '<span class="t-Badge t-Badge--normal">Not Assigned Now</span>'
       end as current_position_badge

from fleet_bike_assignments ba

join fleet_bikes b
  on b.bike_id = ba.bike_id

left join vw_fleet_bike_current vc
  on vc.bike_id = ba.bike_id

left join vw_hr_employee_list e
  on e.emp_id = ba.emp_id

left join assignment_project ap
  on ap.bike_assign_id = ba.bike_assign_id

left join hr_projects p
  on p.project_id = ap.project_id

left join ref_cities c
  on c.city_id = ap.city_id

where
      ------------------------------------------------------------------
      -- No full load if both filters are blank
      ------------------------------------------------------------------
      (
          v('P339_PLATE_NO') is not null
          or v('P339_EMP_ID') is not null
      )

  and (
          v('P339_PLATE_NO') is null
          or upper(b.plate_no) like '%' || upper(v('P339_PLATE_NO')) || '%'
          or upper(b.bike_code) like '%' || upper(v('P339_PLATE_NO')) || '%'
      )

  and (
          v('P339_EMP_ID') is null
          or ba.emp_id = to_number(v('P339_EMP_ID'))
      )

order by ba.assign_dt desc,
         ba.bike_assign_id desc;
