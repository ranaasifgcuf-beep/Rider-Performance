create or replace package hr_pay_mode_pkg as
  procedure add_pay_mode(
    p_emp_id          number,
    p_pay_mode_code   varchar2,
    p_effective_from  date default trunc(sysdate),
    p_is_primary      char default 'N',
    p_bank_name       varchar2 default null,
    p_iban_no         varchar2 default null,
    p_account_name    varchar2 default null,
    p_c3_card_no      varchar2 default null,
    p_remarks         varchar2 default null
  );
end;
/
