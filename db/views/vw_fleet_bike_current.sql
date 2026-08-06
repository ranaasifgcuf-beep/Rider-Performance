CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_FLEET_BIKE_CURRENT" ("BIKE_ID", "BIKE_CODE", "PLATE_NO", "PLATE_EMIRATE", "CHASSIS_NO", "ENGINE_NO", "MODEL_ID", "MODEL_NAME", "MODEL_YEAR", "MODEL_YEAR_LABEL", "COLOR_ID", "COLOR_NAME", "OWNERSHIP_TYPE", "VENDOR_ID", "VENDOR_NAME", "VENDOR_SHORT_NAME", "PURCHASE_DT", "PURCHASE_AMOUNT", "CURRENT_MONTHLY_RENT", "CONTRACT_START_DT", "CONTRACT_END_DT", "REMARKS", "IS_ACTIVE", "STATUS_TXN_ID", "BIKE_STATUS_CODE", "BIKE_STATUS_NAME", "STATUS_FROM_DT", "STATUS_TO_DT", "STATUS_REASON_CODE", "STATUS_REMARKS", "CUSTODY_TXN_ID", "CUSTODY_TYPE_CODE", "CUSTODY_TYPE_NAME", "LOCATION_ID", "CUSTODY_LOCATION_NAME", "CUSTODY_FROM_DT", "CUSTODY_TO_DT", "CUSTODY_REASON_CODE", "CUSTODY_REMARKS", "CURRENT_BIKE_ASSIGN_ID", "CURRENT_EMP_ID", "EMPLOYEE_NAME", "EMP_CODE", "CURRENT_PROJECT", "NATIONALITY", "CURRENT_ASSIGN_DT", "CURRENT_EXPECTED_RETURN_DT", "CURRENT_ISSUE_CONDITION", "CURRENT_ASSIGN_REMARKS", "MULKIYA_DOC_ID", "MULKIYA_NO", "MULKIYA_ISSUE_DT", "MULKIYA_EXPIRY_DT", "INSURANCE_DOC_ID", "INSURANCE_NO", "INSURANCE_ISSUE_DT", "INSURANCE_EXPIRY_DT", "MULKIYA_BUCKET", "INSURANCE_BUCKET", "UTILIZATION_BUCKET") AS 
  with curr_assign as (
    select a.*
      from (
            select a.*,
                   row_number() over (
                       partition by a.bike_id
                       order by a.assign_dt desc, a.bike_assign_id desc
                   ) rn
              from fleet_bike_assignments a
             where a.status_code = 'ACTIVE'
               and a.return_dt is null
           ) a
     where a.rn = 1
),
curr_status as (
    select s.*
      from (
            select s.*,
                   row_number() over (
                       partition by s.bike_id
                       order by s.from_dt desc, s.status_txn_id desc
                   ) rn
              from fleet_bike_status_txns s
             where s.to_dt is null
           ) s
     where s.rn = 1
),
curr_custody as (
    select c.*
      from (
            select c.*,
                   row_number() over (
                       partition by c.bike_id
                       order by c.from_dt desc, c.custody_txn_id desc
                   ) rn
              from fleet_bike_custody_txns c
             where c.to_dt is null
           ) c
     where c.rn = 1
)
select b.bike_id,
       b.bike_code,
       b.plate_no,
       b.plate_emirate,
       b.chassis_no,
       b.engine_no,
       b.model_id,
       m.model_name,
       b.model_year,
       y.year_label as model_year_label,
       b.color_id,
       c.color_name,
       b.ownership_type,
       b.vendor_id,
       fs.supplier_name as vendor_name,
       fs.short_name as vendor_short_name,
       b.purchase_dt,
       b.purchase_amount,
       b.current_monthly_rent,
       b.contract_start_dt,
       b.contract_end_dt,
       b.remarks,
       b.is_active,

       st.status_txn_id,
       st.bike_status_code,
       rs.status_name as bike_status_name,
       st.from_dt as status_from_dt,
       st.to_dt as status_to_dt,
       st.reason_code as status_reason_code,
       st.remarks as status_remarks,

       ct.custody_txn_id,
       ct.custody_type_code,
       rct.custody_type_name,
       ct.location_id,
       rcl.location_name as custody_location_name,
       ct.from_dt as custody_from_dt,
       ct.to_dt as custody_to_dt,
       ct.reason_code as custody_reason_code,
       ct.remarks as custody_remarks,

       ca.bike_assign_id as current_bike_assign_id,

       ca.emp_id as current_emp_id,
       emp.FULL_EMPLOYEE_NAME as employee_name,
       emp.EMP_CODE,
       emp.CURRENT_PROJECT,
       emp.nationality,
       
       ca.assign_dt as current_assign_dt,
       ca.expected_return_dt as current_expected_return_dt,
       ca.issue_condition as current_issue_condition,
       ca.remarks as current_assign_remarks,

        d.mulkiya_doc_id,
       d.mulkiya_no,
       d.mulkiya_issue_dt,
       d.mulkiya_expiry_dt,

       d.insurance_doc_id,
       d.insurance_no,
       d.insurance_issue_dt,
       d.insurance_expiry_dt,

       case
         when d.mulkiya_expiry_dt is null then 'NO_DATE'
         when d.mulkiya_expiry_dt < trunc(sysdate) then 'EXPIRED'
         when d.mulkiya_expiry_dt <= trunc(sysdate) + 30 then 'DUE_SOON'
         else 'VALID'
       end as mulkiya_bucket,

       case
         when d.insurance_expiry_dt is null then 'NO_DATE'
         when d.insurance_expiry_dt < trunc(sysdate) then 'EXPIRED'
         when d.insurance_expiry_dt <= trunc(sysdate) + 30 then 'DUE_SOON'
         else 'VALID'
       end as insurance_bucket,

       case
         when st.bike_status_code = 'ASSIGNED' then 'PRODUCTIVE'
         when st.bike_status_code = 'AVAILABLE' then 'IDLE_READY'
         when st.bike_status_code in ('ACCIDENT','MAINTENANCE') then 'IDLE_REPAIR'
         when st.bike_status_code in ('IMPOUND','POLICE_CUSTODY') then 'IDLE_LEGAL'
         else 'OTHER'
       end as utilization_bucket

  from fleet_bikes b
  left join curr_assign ca
    on ca.bike_id = b.bike_id
  left join curr_status st
    on st.bike_id = b.bike_id
  left join fleet_ref_bike_statuses rs
    on rs.status_code = st.bike_status_code
  left join curr_custody ct
    on ct.bike_id = b.bike_id
  left join fleet_ref_custody_types rct
    on rct.custody_type_code = ct.custody_type_code
  left join fleet_ref_custody_locations rcl
    on rcl.location_id = ct.location_id
  left join fleet_ref_models m
    on m.model_id = b.model_id
  left join core_years y
    on y.year_no = b.model_year
  left join fleet_ref_colors c
    on c.color_id = b.color_id
  left join fin_suppliers fs
    on fs.supplier_id = b.vendor_id
  left join vw_fleet_bike_doc_summary d
    on d.bike_id = b.bike_id
    left join VW_HR_EMPLOYEE_LIST emp
    on emp.emp_id = ca.emp_id;
