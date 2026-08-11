CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_HR_ORG_DOCS" ("ORG_DOC_ID", "ORG_ID", "ORG_CODE", "ORG_NAME", "DOC_TYPE_CODE", "DOC_TYPE_NAME", "DOC_NO", "ISSUE_DT", "EXPIRY_DT", "IS_CURRENT", "IS_ACTIVE", "FILE_REF", "REMARKS", "EXPIRY_IN_DAYS", "EXPIRY_STATUS", "CREATED_BY", "CREATED_DT", "UPDATED_BY", "UPDATED_DT") AS
select d.org_doc_id,
       d.org_id,
       o.org_code,
       o.org_name,

       d.doc_type_code,
       t.doc_type_name,

       d.doc_no,
       d.issue_dt,
       d.expiry_dt,
       d.is_current,
       d.is_active,
       d.file_ref,
       d.remarks,

       case
           when d.expiry_dt is null then null
           else trunc(d.expiry_dt) - trunc(cast(systimestamp at time zone 'Asia/Dubai' as date))
       end as expiry_in_days,

       case
           when d.expiry_dt is null then 'NO_EXPIRY'
           when trunc(d.expiry_dt) < trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) then 'EXPIRED'
           when trunc(d.expiry_dt) <= trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)) + 30 then 'EXPIRING_SOON'
           else 'VALID'
       end as expiry_status,

       d.created_by,
       d.created_dt,
       d.updated_by,
       d.updated_dt

  from hr_org_docs d
  join hr_orgs o
    on o.org_id = d.org_id
  left join hr_org_doc_type_master t
    on t.doc_type_code = d.doc_type_code;
