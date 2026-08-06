CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_EMP_SUPPLIER_REQUIRED" 
before insert or update of worker_type, supplier_id on hr_employees
for each row
begin
  if :new.worker_type = 'SUBCONTRACT' and :new.supplier_id is null then
    raise_application_error(-20001, 'Supplier is required when Worker Type is SUBCONTRACT.');
  end if;

  if :new.worker_type = 'DIRECT' then
    :new.supplier_id := null;
    :new.contract_ref := null;
  end if;
end;
/

ALTER TRIGGER "TRG_EMP_SUPPLIER_REQUIRED" ENABLE;
