CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_EMP_SIM_SUMMARY" ("EMP_ID", "ACTIVE_SIM_COUNT", "ACTIVE_SIM_NUMBERS", "FIRST_SIM_ASSIGN_DT", "LAST_SIM_ASSIGN_DT", "TOTAL_MONTHLY_SIM_COST", "SIM_SUMMARY_BADGE") AS 
  select emp_id,
       count(*) as active_sim_count,
       listagg(mobile_no, ', ') within group (order by assign_dt, sim_id) as active_sim_numbers,
       min(assign_dt) as first_sim_assign_dt,
       max(assign_dt) as last_sim_assign_dt,
       sum(nvl(monthly_cost,0)) as total_monthly_sim_cost,

       case
           when count(*) = 0 then
               '<span class="t-Badge t-Badge--normal">No SIM</span>'
           when count(*) = 1 then
               '<span class="t-Badge t-Badge--warning">' ||
               apex_escape.html(max(mobile_no)) ||
               '</span>'
           else
               '<span class="t-Badge t-Badge--danger">' ||
               count(*) || ' SIMs: ' ||
               apex_escape.html(listagg(mobile_no, ', ') within group (order by assign_dt, sim_id)) ||
               '</span>'
       end as sim_summary_badge

  from vw_hr_emp_current_sims
 group by emp_id;
