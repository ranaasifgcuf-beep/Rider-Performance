CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_BIKE_READINESS" ("EMP_ID", "EMP_CODE", "FULL_EMPLOYEE_NAME", "JOB_ID", "JOB_NAME", "BIKE_REQUIRED_YN", "CURRENT_BIKE_ID", "CURRENT_BIKE_DISPLAY", "CURRENT_BIKE_ASSIGN_DT", "OPEN_REQUEST_ID", "OPEN_REQUEST_TYPE", "OPEN_REQUEST_STATUS", "OPEN_REQUEST_PRIORITY", "BIKE_READINESS_CODE") AS 
  select e.emp_id,
       e.emp_code,
       e.full_employee_name,
       e.job_id,
       e.job_name,

       nvl(j.bike_required_yn, 'N') as bike_required_yn,

       cb.bike_id        as current_bike_id,
      cb.bike_display   as current_bike_display,
       cb.assign_dt      as current_bike_assign_dt,

       br.request_id     as open_request_id,
       br.request_type   as open_request_type,
       br.request_status as open_request_status,
       br.priority       as open_request_priority,

       case
           when nvl(j.bike_required_yn, 'N') = 'N' then
               'NOT_REQUIRED'

           when cb.bike_id is not null
            and br.request_id is not null then
               'REPLACEMENT_REQUESTED'

           when cb.bike_id is not null then
               'ASSIGNED'

           when br.request_id is not null then
               'REQUEST_OPEN'

           else
               'NEEDED'
       end as bike_readiness_code

from vw_hr_employee_list e

left join ref_jobs j
       on j.job_id = e.job_id

left join VW_HR_EMP_CURRENT_BIKE cb
       on cb.emp_id = e.emp_id

left join vw_hr_emp_open_bike_req br
       on br.emp_id = e.emp_id;
