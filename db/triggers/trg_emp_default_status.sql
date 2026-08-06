CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_EMP_DEFAULT_STATUS" 
for insert on hr_employees
compound trigger

    type t_emp_ids is table of hr_employees.emp_id%type index by pls_integer;
    g_emp_ids t_emp_ids;
    g_count   pls_integer := 0;

after each row is
begin
    ------------------------------------------------------------------
    -- 1. Create operational default status
    ------------------------------------------------------------------
    insert into hr_emp_status_hist (
        emp_id,
        status_code,
        effective_from,
        effective_to,
        remarks
    )
    values (
        :new.emp_id,
        'PIPELINE',
        trunc(cast(systimestamp at time zone 'Asia/Dubai' as date)),
        null,
        'Auto set on employee creation'
    );

    ------------------------------------------------------------------
    -- 2. Store employee id for legal profile creation after statement
    ------------------------------------------------------------------
    g_count := g_count + 1;
    g_emp_ids(g_count) := :new.emp_id;
end after each row;


after statement is
begin
    ------------------------------------------------------------------
    -- 3. Auto-create legal profile
    -- Legal status history will be created by HR_EMP_LEGAL_STATUS_AIU
    ------------------------------------------------------------------
    for i in 1 .. g_count loop
        hr_legal_profile_pkg.ensure_profile(g_emp_ids(i));
    end loop;
end after statement;

end trg_emp_default_status;
/

ALTER TRIGGER "TRG_EMP_DEFAULT_STATUS" ENABLE;
