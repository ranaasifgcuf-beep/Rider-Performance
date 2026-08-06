CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_ASSET_CONTROL" ("EMP_ID", "EMP_CODE", "FULL_EMPLOYEE_NAME", "CURRENT_STATUS_CODE", "CURRENT_STATUS_NAME", "CURRENT_LEGAL_CODE", "CURRENT_LEGAL_NAME", "JOB_ID", "JOB_NAME", "WORKER_TYPE", "SUPPLIER_NAME", "BIKE_REQUIRED_YN", "CURRENT_BIKE_ID", "CURRENT_BIKE_DISPLAY", "CURRENT_BIKE_ASSIGN_DT", "OPEN_BIKE_REQUEST_ID", "OPEN_BIKE_REQUEST_TYPE", "OPEN_BIKE_REQUEST_STATUS", "HAS_BIKE_YN", "ACTIVE_ASSIGNMENT_YN", "ACTUALLY_WORKING_YN", "CURRENT_BIKE_BADGE", "ASSET_RISK_CODE", "ASSET_RISK_BADGE", "CAN_PENDING_ACTIVE_YN", "CAN_MARK_ACTIVE_YN", "CAN_BACK_PIPELINE_YN") AS 
  select e.emp_id,
       e.emp_code,
       e.full_employee_name,
       e.current_status_code,
       e.current_status_name,
       e.current_legal_code,
       e.current_legal_name,
       e.job_id,
       e.job_name,
       e.worker_type,
       e.supplier_name,

       nvl(j.bike_required_yn, 'N') as bike_required_yn,

       cb.bike_id      as current_bike_id,
       cb.bike_display as current_bike_display,
       cb.assign_dt    as current_bike_assign_dt,

       br.request_id     as open_bike_request_id,
       br.request_type   as open_bike_request_type,
       br.request_status as open_bike_request_status,

       case
           when cb.bike_id is not null then 'Y'
           else 'N'
       end as has_bike_yn,

       case
           when exists (
                select 1
                  from hr_assignments a
                 where a.emp_id = e.emp_id
                   and a.end_dt is null
           ) then 'Y'
           else 'N'
       end as active_assignment_yn,

       case
           when upper(nvl(e.current_status_code, 'X')) = 'ACTIVE'
            and exists (
                select 1
                  from hr_assignments a
                 where a.emp_id = e.emp_id
                   and a.end_dt is null
           ) then 'Y'
           else 'N'
       end as actually_working_yn,

       ------------------------------------------------------------------
       -- Bike badge for all pages
       ------------------------------------------------------------------
       case
           when cb.bike_id is not null then
               '<span class="t-Badge t-Badge--success">' ||
               apex_escape.html(cb.bike_display) ||
               '</span>'
           else
               '<span class="t-Badge t-Badge--normal">No Bike</span>'
       end as current_bike_badge,

       ------------------------------------------------------------------
       -- Asset risk code
       ------------------------------------------------------------------
       case
           when cb.bike_id is null then
               'NO_BIKE'

           when upper(nvl(e.current_status_code, 'X')) = 'ACTIVE'
            and exists (
                select 1
                  from hr_assignments a
                 where a.emp_id = e.emp_id
                   and a.end_dt is null
           ) then
               'BIKE_OK'

           when replace(upper(nvl(e.current_legal_code, 'NOT_SET')), 'LEGAL_', '') in (
                'ABSCONDING',
                'ABSCONDER'
           ) then
               'BIKE_RECOVERY_PENDING'

           when upper(nvl(e.current_status_code, 'X')) = 'PENDING_ACTIVE' then
               'BIKE_WITH_PENDING_ACTIVE'

           when upper(nvl(e.current_status_code, 'X')) in (
                'READY_TO_ONBOARD',
                'ONBOARDING'
           ) then
               'BIKE_ASSIGNED_BEFORE_ACTIVE'

           when upper(nvl(e.current_status_code, 'X')) = 'VACATION' then
               'BIKE_RETURN_REQUIRED'

           when upper(nvl(e.current_status_code, 'X')) in (
                'OFFBOARD',
                'OFFBOARD_QUEUE'
           ) then
               'BIKE_CLEARANCE_PENDING'

           when upper(nvl(e.current_status_code, 'X')) = 'ACCIDENT' then
               'BIKE_RECOVERY_REQUIRED'

           when upper(nvl(e.current_status_code, 'X')) = 'ABSCONDER' then
               'BIKE_RECOVERY_PENDING'

           else
               'BIKE_WITH_NON_WORKING_EMPLOYEE'
       end as asset_risk_code,

       ------------------------------------------------------------------
       -- Asset risk badge for APEX
       ------------------------------------------------------------------
       case
           when cb.bike_id is null then
               '<span class="t-Badge t-Badge--normal">No Asset Risk</span>'

           when upper(nvl(e.current_status_code, 'X')) = 'ACTIVE'
            and exists (
                select 1
                  from hr_assignments a
                 where a.emp_id = e.emp_id
                   and a.end_dt is null
           ) then
               '<span class="t-Badge t-Badge--success">Bike OK</span>'

           when replace(upper(nvl(e.current_legal_code, 'NOT_SET')), 'LEGAL_', '') in (
                'ABSCONDING',
                'ABSCONDER'
           ) then
               '<span class="t-Badge t-Badge--danger">Bike Recovery Pending</span>'

           when upper(nvl(e.current_status_code, 'X')) = 'PENDING_ACTIVE' then
               '<span class="t-Badge t-Badge--warning">Bike With Pending Active</span>'

           when upper(nvl(e.current_status_code, 'X')) in (
                'READY_TO_ONBOARD',
                'ONBOARDING'
           ) then
               '<span class="t-Badge t-Badge--warning">Bike Assigned Before Active</span>'

           when upper(nvl(e.current_status_code, 'X')) = 'VACATION' then
               '<span class="t-Badge t-Badge--danger">Bike Return Required</span>'

           when upper(nvl(e.current_status_code, 'X')) in (
                'OFFBOARD',
                'OFFBOARD_QUEUE'
           ) then
               '<span class="t-Badge t-Badge--danger">Bike Clearance Pending</span>'

           when upper(nvl(e.current_status_code, 'X')) = 'ACCIDENT' then
               '<span class="t-Badge t-Badge--danger">Bike Recovery Required</span>'

           when upper(nvl(e.current_status_code, 'X')) = 'ABSCONDER' then
               '<span class="t-Badge t-Badge--danger">Bike Recovery Pending</span>'

           else
               '<span class="t-Badge t-Badge--danger">Bike With Non-Working Employee</span>'
       end as asset_risk_badge,

       ------------------------------------------------------------------
       -- Can move Ready To Onboard -> Pending Active?
       ------------------------------------------------------------------
       case
           when upper(nvl(e.current_status_code, 'X')) in (
                    'READY_TO_ONBOARD',
                    'ONBOARDING'
                )
            and replace(upper(nvl(e.current_legal_code, 'NOT_SET')), 'LEGAL_', '') not in (
                    'ABSCONDING',
                    'ABSCONDER',
                    'CANCELLED',
                    'CANCELLED_MOHRE',
                    'CANCELLED_ICP'
                )
            and (
                    nvl(j.bike_required_yn, 'N') = 'N'
                    or cb.bike_id is not null
                )
           then 'Y'
           else 'N'
       end as can_pending_active_yn,

       ------------------------------------------------------------------
       -- Can move Pending Active -> Active?
       ------------------------------------------------------------------
       case
           when upper(nvl(e.current_status_code, 'X')) = 'PENDING_ACTIVE'
            and replace(upper(nvl(e.current_legal_code, 'NOT_SET')), 'LEGAL_', '') not in (
                    'ABSCONDING',
                    'ABSCONDER',
                    'CANCELLED',
                    'CANCELLED_MOHRE',
                    'CANCELLED_ICP'
                )
            and exists (
                    select 1
                      from hr_assignments a
                     where a.emp_id = e.emp_id
                       and a.end_dt is null
                )
            and (
                    nvl(j.bike_required_yn, 'N') = 'N'
                    or cb.bike_id is not null
                )
           then 'Y'
           else 'N'
       end as can_mark_active_yn,

       ------------------------------------------------------------------
       -- Can move wrongly marked Ready To Onboard back to Pipeline?
       ------------------------------------------------------------------
       case
           when upper(nvl(e.current_status_code, 'X')) in (
                    'READY_TO_ONBOARD',
                    'ONBOARDING'
                )
            and cb.bike_id is null
            and br.request_id is null
            and not exists (
                    select 1
                      from hr_assignments a
                     where a.emp_id = e.emp_id
                       and a.end_dt is null
                )
           then 'Y'
           else 'N'
       end as can_back_pipeline_yn

from vw_hr_employee_list e

left join ref_jobs j
       on j.job_id = e.job_id

left join vw_hr_emp_current_bike cb
       on cb.emp_id = e.emp_id

left join vw_hr_emp_open_bike_req br
       on br.emp_id = e.emp_id;
