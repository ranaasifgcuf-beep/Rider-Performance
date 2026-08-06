CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_FLEET_BIKE_DOC_SUMMARY" ("BIKE_ID", "MULKIYA_DOC_ID", "MULKIYA_NO", "MULKIYA_ISSUE_DT", "MULKIYA_EXPIRY_DT", "MULKIYA_FILE_NAME", "INSURANCE_DOC_ID", "INSURANCE_NO", "INSURANCE_ISSUE_DT", "INSURANCE_EXPIRY_DT", "INSURANCE_FILE_NAME") AS 
  select bike_id,
max(mulkiya_doc_id) as mulkiya_doc_id,
max(mulkiya_no) as mulkiya_no,
max(mulkiya_issue_dt) as mulkiya_issue_dt,
max(mulkiya_expiry_dt) as mulkiya_expiry_dt,
max(mulkiya_file_name) as mulkiya_file_name,
max(insurance_doc_id) as insurance_doc_id,
max(insurance_no) as insurance_no,
max(insurance_issue_dt) as insurance_issue_dt,
max(insurance_expiry_dt) as insurance_expiry_dt,
max(insurance_file_name) as insurance_file_name
from (
select bike_id,
case when doc_type = 'MULKIYA'   then bike_doc_id end as mulkiya_doc_id,
case when doc_type = 'MULKIYA'   then doc_no end      as mulkiya_no,
 case when doc_type = 'MULKIYA'   then issue_dt end   as mulkiya_issue_dt,
     case when doc_type = 'MULKIYA'   then expiry_dt end   as mulkiya_expiry_dt,
      case when doc_type = 'MULKIYA'   then file_name end  as mulkiya_file_name,

       case when doc_type = 'INSURANCE' then bike_doc_id end as insurance_doc_id,
      case when doc_type = 'INSURANCE' then doc_no end      as insurance_no,
       case when doc_type = 'INSURANCE' then issue_dt end    as insurance_issue_dt,
      case when doc_type = 'INSURANCE' then expiry_dt end  as insurance_expiry_dt,
    case when doc_type = 'INSURANCE' then file_name end   as insurance_file_name
  from vw_fleet_bike_doc_latest
) group by bike_id;
