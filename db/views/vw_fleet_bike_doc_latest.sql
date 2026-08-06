CREATE OR REPLACE FORCE EDITIONABLE VIEW "VW_FLEET_BIKE_DOC_LATEST" ("BIKE_ID", "DOC_TYPE", "BIKE_DOC_ID", "DOC_NO", "ISSUE_DT", "EXPIRY_DT", "FILE_NAME", "IS_CURRENT") AS 
  with x as (
    select d.bike_id,
           upper(trim(d.doc_type)) as doc_type,
           d.bike_doc_id,
           d.doc_no,
           d.issue_dt,
           d.expiry_dt,
           d.file_name,
           d.is_current,
           row_number() over (
               partition by d.bike_id, upper(trim(d.doc_type))
               order by case when nvl(d.is_current,'N') = 'Y' then 1 else 2 end,
                        nvl(d.expiry_dt, date '1900-01-01') desc,
                        d.bike_doc_id desc
           ) rn
      from fleet_bike_docs d
)
select bike_id,
       doc_type,
       bike_doc_id,
       doc_no,
       issue_dt,
       expiry_dt,
       file_name,
       is_current
  from x
 where rn = 1;
