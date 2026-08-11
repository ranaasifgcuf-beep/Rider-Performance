select org_doc_id,
       org_id,

       org_code,
       org_name,

       doc_type_code,
       doc_type_name as document,

       doc_no as document_number,

       issue_dt,
       expiry_dt,
       expiry_in_days,

       case expiry_status
           when 'NO_EXPIRY' then
               '<span class="t-Badge">No Expiry</span>'
           when 'EXPIRED' then
               '<span class="t-Badge t-Badge--danger">Expired</span>'
           when 'EXPIRING_SOON' then
               '<span class="t-Badge t-Badge--warning">Near Expiry</span>'
           when 'VALID' then
               '<span class="t-Badge t-Badge--success">Active</span>'
           else
               '<span class="t-Badge">' || apex_escape.html(expiry_status) || '</span>'
       end as expiry_status,

       case is_current
           when 'Y' then '<span class="t-Badge t-Badge--success">Yes</span>'
           else '<span class="t-Badge">No</span>'
       end as is_current,

       case is_active
           when 'Y' then '<span class="t-Badge t-Badge--success">Active</span>'
           else '<span class="t-Badge t-Badge--danger">Inactive</span>'
       end as is_active,

       remarks

  from vw_hr_org_docs
 where (:P_ORG_ID is null or org_id = :P_ORG_ID)
 order by org_name, doc_type_name, issue_dt desc;
