CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_ORG_DOC_CURRENT" 
after insert or update of is_current on hr_org_docs
for each row
begin
  if :new.is_current = 'Y' then
    update hr_org_docs
       set is_current = 'N',
           updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_dt = systimestamp
     where org_id = :new.org_id
       and doc_type_code = :new.doc_type_code
       and org_doc_id <> :new.org_doc_id
       and is_current = 'Y';
  end if;
end;
/

ALTER TRIGGER "TRG_HR_ORG_DOC_CURRENT" ENABLE;
