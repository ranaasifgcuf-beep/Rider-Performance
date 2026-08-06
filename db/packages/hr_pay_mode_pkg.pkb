create or replace package body hr_pay_mode_pkg as

  procedure add_pay_mode(
    p_emp_id          number,
    p_pay_mode_code   varchar2,
    p_effective_from  date,
    p_is_primary      char,
    p_bank_name       varchar2,
    p_iban_no         varchar2,
    p_account_name    varchar2,
    p_c3_card_no      varchar2,
    p_remarks         varchar2
  ) is
  begin

update hr_emp_pay_modes
       set is_primary   = 'N',
           is_active    = 'N',
           effective_to = sysdate
     where emp_id = p_emp_id
       and is_primary = 'Y'
       and effective_to  is null;

    insert into hr_emp_pay_modes (
      emp_id,
      pay_mode_code,
      effective_from,
      is_primary,
      is_active,
      bank_name,
      iban_no,
      account_name,
      c3_card_no,
      remarks
    )
    values (
      p_emp_id,
      upper(trim(p_pay_mode_code)),
      p_effective_from,
      nvl(p_is_primary,'N'),
      'Y',
      p_bank_name,
      p_iban_no,
      p_account_name,
      p_c3_card_no,
      p_remarks
    );

  end;

end;
/
