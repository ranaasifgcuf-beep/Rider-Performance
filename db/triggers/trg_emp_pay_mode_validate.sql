CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_EMP_PAY_MODE_VALIDATE" 
before insert or update on hr_emp_pay_modes
for each row
begin
  if :new.pay_mode_code = 'BANK' then
    if :new.iban_no is null then
      raise_application_error(-20021, 'IBAN is required for Bank pay mode.');
    end if;
  end if;

  if :new.pay_mode_code = 'C3' then
    if :new.c3_card_no is null then
      raise_application_error(-20022, 'C3 Card Number is required for C3 pay mode.');
    end if;
  end if;

  if :new.pay_mode_code = 'CSH' then
    :new.bank_name    := null;
    :new.iban_no      := null;
    :new.account_name := null;
    :new.c3_card_no   := null;
  elsif :new.pay_mode_code = 'BANK' then
    :new.c3_card_no   := null;
  elsif :new.pay_mode_code = 'C3' then
    :new.bank_name    := null;
    :new.iban_no      := null;
    :new.account_name := null;
  end if;
end;
/

ALTER TRIGGER "TRG_EMP_PAY_MODE_VALIDATE" ENABLE;
