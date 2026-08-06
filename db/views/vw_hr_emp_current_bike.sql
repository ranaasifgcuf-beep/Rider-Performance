CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_CURRENT_BIKE" ("EMP_ID", "BIKE_ID", "BIKE_CODE", "PLATE_NO", "ASSIGN_DT", "BIKE_DISPLAY") AS 
  with x as (
    select ba.emp_id,
           ba.bike_id,
           ba.assign_dt,
           ba.BIKE_ASSIGN_ID,
           row_number() over (
               partition by ba.emp_id
               order by ba.assign_dt desc, ba.BIKE_ASSIGN_ID desc
           ) rn
      from fleet_bike_assignments ba
     where ba.return_dt is null
)
select x.emp_id,
       x.bike_id,
       b.bike_code,
       b.plate_no,
       x.assign_dt,
       nvl(b.plate_no,b.bike_code) as bike_display
  from x
  join fleet_bikes b
    on b.bike_id = x.bike_id
 where x.rn = 1;
