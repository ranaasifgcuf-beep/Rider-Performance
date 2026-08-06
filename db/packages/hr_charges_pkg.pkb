create or replace package body hr_charges_pkg as

    procedure raise_err(p_msg in varchar2) is
    begin
        raise_application_error(-20001, p_msg);
    end;

    procedure append_remarks (
        p_old_remarks in out varchar2,
        p_new_remarks in varchar2
    ) is
    begin
        if p_new_remarks is not null then
            if p_old_remarks is null then
                p_old_remarks := p_new_remarks;
            else
                p_old_remarks := p_old_remarks || ' | ' || p_new_remarks;
            end if;
        end if;
    end append_remarks;

    procedure validate_charge (
        p_emp_charge_id           in hr_emp_charges.emp_charge_id%type default null,
        p_emp_id                  in hr_emp_charges.emp_id%type,
        p_charge_type             in hr_emp_charges.charge_type%type,
        p_recurrence_type         in hr_emp_charges.recurrence_type%type,
        p_charge_ts               in hr_emp_charges.charge_ts%type,
        p_amount                  in hr_emp_charges.amount%type,
        p_source_start_dt         in hr_emp_charges.source_start_dt%type,
        p_source_end_dt           in hr_emp_charges.source_end_dt%type,
        p_charge_to_employee_yn   in hr_emp_charges.charge_to_employee_yn%type,
        p_excluded_from_charge_yn in hr_emp_charges.excluded_from_charge_yn%type,
        p_approval_status         in hr_emp_charges.approval_status%type
    ) is
        l_cnt number;
    begin
        if p_emp_id is null then
            raise_err('Employee is required.');
        end if;

        if p_charge_type is null then
            raise_err('Charge type is required.');
        end if;

        if p_recurrence_type is null then
            raise_err('Recurrence type is required.');
        end if;

        if p_charge_ts is null then
            raise_err('Charge timestamp is required.');
        end if;

        if nvl(p_amount,0) <= 0 then
            raise_err('Charge amount must be greater than zero.');
        end if;

        if p_charge_to_employee_yn not in ('Y','N') then
            raise_err('Charge to employee must be Y or N.');
        end if;

        if p_excluded_from_charge_yn not in ('Y','N') then
            raise_err('Excluded from charge must be Y or N.');
        end if;

        if p_approval_status not in ('DRAFT','APPROVED','CANCELLED','CLOSED','BAD_DEBT') then
            raise_err('Invalid approval status.');
        end if;

        if p_recurrence_type in ('YEARLY','MONTHLY') then
            if p_source_start_dt is null or p_source_end_dt is null then
                raise_err('Source Start Date and Source End Date are required for recurring charges.');
            end if;

            if p_source_end_dt < p_source_start_dt then
                raise_err('Source End Date cannot be earlier than Source Start Date.');
            end if;

            select count(*)
              into l_cnt
              from hr_emp_charges c
             where c.emp_id = p_emp_id
               and c.charge_type = p_charge_type
               and c.recurrence_type = p_recurrence_type
               and c.approval_status <> 'CANCELLED'
               and nvl(c.emp_charge_id,-1) <> nvl(p_emp_charge_id,-1)
               and p_source_start_dt <= nvl(c.source_end_dt, p_source_start_dt)
               and p_source_end_dt   >= nvl(c.source_start_dt, p_source_end_dt);

            if l_cnt > 0 then
                raise_err('A recurring charge already exists for this employee within the selected charge period.');
            end if;
        end if;
    end validate_charge;

    procedure refresh_charge_header_status (
        p_emp_charge_id in hr_emp_charges.emp_charge_id%type
    ) is
        l_pending_cnt number;
        l_open_cnt    number;
        l_bad_debt_cnt number;
    begin
        select count(*)
          into l_open_cnt
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id
           and status_code in ('PENDING','ON_HOLD');

        select count(*)
          into l_pending_cnt
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id
           and status_code = 'PENDING';

        select count(*)
          into l_bad_debt_cnt
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id
           and status_code = 'BAD_DEBT';

        if l_open_cnt = 0 then
            if l_bad_debt_cnt > 0 then
                update hr_emp_charges
                   set approval_status = 'CLOSED',
                       payroll_processed_yn = 'Y'
                 where emp_charge_id = p_emp_charge_id
                   and approval_status not in ('CANCELLED','BAD_DEBT');
            else
                update hr_emp_charges
                   set approval_status = 'CLOSED',
                       payroll_processed_yn = 'Y'
                 where emp_charge_id = p_emp_charge_id
                   and approval_status not in ('CANCELLED','BAD_DEBT');
            end if;
        else
            update hr_emp_charges
               set payroll_processed_yn = 'N'
             where emp_charge_id = p_emp_charge_id
               and approval_status = 'CLOSED';
        end if;
    end refresh_charge_header_status;

    procedure create_charge (
        p_emp_id                    in hr_emp_charges.emp_id%type,
        p_charge_type               in hr_emp_charges.charge_type%type,
        p_recurrence_type           in hr_emp_charges.recurrence_type%type default 'ONE_TIME',
        p_charge_ts                 in hr_emp_charges.charge_ts%type,
        p_amount                    in hr_emp_charges.amount%type,
        p_source_start_dt           in hr_emp_charges.source_start_dt%type default null,
        p_source_end_dt             in hr_emp_charges.source_end_dt%type default null,
        p_source_table_name         in hr_emp_charges.source_table_name%type default null,
        p_source_row_id             in hr_emp_charges.source_row_id%type default null,
        p_bike_id                   in hr_emp_charges.bike_id%type default null,
        p_charge_to_employee_yn     in hr_emp_charges.charge_to_employee_yn%type default 'Y',
        p_excluded_from_charge_yn   in hr_emp_charges.excluded_from_charge_yn%type default 'N',
        p_approval_status           in hr_emp_charges.approval_status%type default 'APPROVED',
        p_payroll_deduction_code    in hr_emp_charges.payroll_deduction_code%type default null,
        p_remarks                   in hr_emp_charges.remarks%type default null,
        p_emp_charge_id             out hr_emp_charges.emp_charge_id%type
    ) is
    begin
        validate_charge(
            p_emp_charge_id           => null,
            p_emp_id                  => p_emp_id,
            p_charge_type             => p_charge_type,
            p_recurrence_type         => p_recurrence_type,
            p_charge_ts               => p_charge_ts,
            p_amount                  => p_amount,
            p_source_start_dt         => p_source_start_dt,
            p_source_end_dt           => p_source_end_dt,
            p_charge_to_employee_yn   => p_charge_to_employee_yn,
            p_excluded_from_charge_yn => p_excluded_from_charge_yn,
            p_approval_status         => p_approval_status
        );

        insert into hr_emp_charges (
            emp_id,
            charge_type,
            recurrence_type,
            charge_ts,
            amount,
            source_start_dt,
            source_end_dt,
            source_table_name,
            source_row_id,
            bike_id,
            charge_to_employee_yn,
            excluded_from_charge_yn,
            approval_status,
            payroll_deduction_code,
            remarks
        ) values (
            p_emp_id,
            p_charge_type,
            p_recurrence_type,
            p_charge_ts,
            p_amount,
            p_source_start_dt,
            p_source_end_dt,
            p_source_table_name,
            p_source_row_id,
            p_bike_id,
            p_charge_to_employee_yn,
            p_excluded_from_charge_yn,
            p_approval_status,
            p_payroll_deduction_code,
            p_remarks
        )
        returning emp_charge_id into p_emp_charge_id;
    end create_charge;

    procedure update_charge (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type,
        p_emp_id                    in hr_emp_charges.emp_id%type,
        p_charge_type               in hr_emp_charges.charge_type%type,
        p_recurrence_type           in hr_emp_charges.recurrence_type%type,
        p_charge_ts                 in hr_emp_charges.charge_ts%type,
        p_amount                    in hr_emp_charges.amount%type,
        p_source_start_dt           in hr_emp_charges.source_start_dt%type default null,
        p_source_end_dt             in hr_emp_charges.source_end_dt%type default null,
        p_source_table_name         in hr_emp_charges.source_table_name%type default null,
        p_source_row_id             in hr_emp_charges.source_row_id%type default null,
        p_bike_id                   in hr_emp_charges.bike_id%type default null,
        p_charge_to_employee_yn     in hr_emp_charges.charge_to_employee_yn%type default 'Y',
        p_excluded_from_charge_yn   in hr_emp_charges.excluded_from_charge_yn%type default 'N',
        p_approval_status           in hr_emp_charges.approval_status%type default 'APPROVED',
        p_payroll_deduction_code    in hr_emp_charges.payroll_deduction_code%type default null,
        p_remarks                   in hr_emp_charges.remarks%type default null
    ) is
    begin
        if p_emp_charge_id is null then
            raise_err('Charge ID is required.');
        end if;

        validate_charge(
            p_emp_charge_id           => p_emp_charge_id,
            p_emp_id                  => p_emp_id,
            p_charge_type             => p_charge_type,
            p_recurrence_type         => p_recurrence_type,
            p_charge_ts               => p_charge_ts,
            p_amount                  => p_amount,
            p_source_start_dt         => p_source_start_dt,
            p_source_end_dt           => p_source_end_dt,
            p_charge_to_employee_yn   => p_charge_to_employee_yn,
            p_excluded_from_charge_yn => p_excluded_from_charge_yn,
            p_approval_status         => p_approval_status
        );

        update hr_emp_charges
           set emp_id                  = p_emp_id,
               charge_type             = p_charge_type,
               recurrence_type         = p_recurrence_type,
               charge_ts               = p_charge_ts,
               amount                  = p_amount,
               source_start_dt         = p_source_start_dt,
               source_end_dt           = p_source_end_dt,
               source_table_name       = p_source_table_name,
               source_row_id           = p_source_row_id,
               bike_id                 = p_bike_id,
               charge_to_employee_yn   = p_charge_to_employee_yn,
               excluded_from_charge_yn = p_excluded_from_charge_yn,
               approval_status         = p_approval_status,
               payroll_deduction_code  = p_payroll_deduction_code,
               remarks                 = p_remarks
         where emp_charge_id = p_emp_charge_id;
    end update_charge;

    procedure create_single_installment (
        p_emp_charge_id             in hr_emp_charge_installments.emp_charge_id%type,
        p_due_dt                    in hr_emp_charge_installments.due_dt%type,
        p_amount                    in hr_emp_charge_installments.amount%type,
        p_remarks                   in hr_emp_charge_installments.remarks%type default null
    ) is
        l_cnt number;
    begin
        if p_emp_charge_id is null then
            raise_err('Charge is required.');
        end if;

        if p_due_dt is null then
            raise_err('Due date is required.');
        end if;

        if nvl(p_amount,0) <= 0 then
            raise_err('Installment amount must be greater than zero.');
        end if;

        select count(*)
          into l_cnt
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id;

        insert into hr_emp_charge_installments (
            emp_charge_id,
            installment_no,
            due_dt,
            amount,
            status_code,
            remarks
        ) values (
            p_emp_charge_id,
            l_cnt + 1,
            p_due_dt,
            p_amount,
            'PENDING',
            p_remarks
        );
    end create_single_installment;

    procedure create_equal_installments (
        p_emp_charge_id             in hr_emp_charge_installments.emp_charge_id%type,
        p_first_due_dt              in date,
        p_no_of_installments        in number,
        p_remarks                   in varchar2 default null
    ) is
        l_amount       number;
        l_base_amt     number;
        l_last_amt     number;
        l_existing_cnt number;
    begin
        if p_emp_charge_id is null then
            raise_err('Charge is required.');
        end if;

        if p_first_due_dt is null then
            raise_err('First due date is required.');
        end if;

        if nvl(p_no_of_installments,0) <= 0 then
            raise_err('Number of installments must be greater than zero.');
        end if;

        select count(*)
          into l_existing_cnt
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id
           and status_code <> 'CANCELLED';

        if l_existing_cnt > 0 then
            raise_err('Installments already exist. Cancel existing installments before regenerating.');
        end if;

        select amount
          into l_amount
          from hr_emp_charges
         where emp_charge_id = p_emp_charge_id;

        l_base_amt := round(l_amount / p_no_of_installments, 2);
        l_last_amt := l_amount - (l_base_amt * (p_no_of_installments - 1));

        for i in 1 .. p_no_of_installments loop
            insert into hr_emp_charge_installments (
                emp_charge_id,
                installment_no,
                due_dt,
                amount,
                status_code,
                remarks
            ) values (
                p_emp_charge_id,
                i,
                add_months(p_first_due_dt, i - 1),
                case when i = p_no_of_installments then l_last_amt else l_base_amt end,
                'PENDING',
                p_remarks
            );
        end loop;
    end create_equal_installments;

    procedure update_installment_status (
        p_installment_id in hr_emp_charge_installments.installment_id%type,
        p_new_status     in hr_emp_charge_installments.status_code%type,
        p_payroll_run_ref in hr_emp_charge_installments.payroll_run_ref%type default null,
        p_hold_from_dt   in hr_emp_charge_installments.hold_from_dt%type default null,
        p_hold_to_dt     in hr_emp_charge_installments.hold_to_dt%type default null,
        p_remarks        in varchar2 default null
    ) is
        l_emp_charge_id number;
        l_old_remarks   varchar2(500);
    begin
        if p_installment_id is null then
            raise_err('Installment is required.');
        end if;

        select emp_charge_id, remarks
          into l_emp_charge_id, l_old_remarks
          from hr_emp_charge_installments
         where installment_id = p_installment_id;

        append_remarks(l_old_remarks, p_remarks);

        update hr_emp_charge_installments
           set status_code     = p_new_status,
               payroll_run_ref = case when p_new_status = 'PROCESSED' then p_payroll_run_ref else payroll_run_ref end,
               processed_ts    = case when p_new_status = 'PROCESSED' then systimestamp else processed_ts end,
               hold_from_dt    = case when p_new_status = 'ON_HOLD' then p_hold_from_dt else hold_from_dt end,
               hold_to_dt      = case when p_new_status = 'ON_HOLD' then p_hold_to_dt else hold_to_dt end,
               remarks         = l_old_remarks
         where installment_id = p_installment_id;

        refresh_charge_header_status(l_emp_charge_id);
    end update_installment_status;

    procedure mark_installment_processed (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_payroll_run_ref           in hr_emp_charge_installments.payroll_run_ref%type default null,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id  => p_installment_id,
            p_new_status      => 'PROCESSED',
            p_payroll_run_ref => p_payroll_run_ref,
            p_remarks         => p_remarks
        );
    end mark_installment_processed;

    procedure mark_installment_hold (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_hold_from_dt              in hr_emp_charge_installments.hold_from_dt%type default trunc(sysdate),
        p_hold_to_dt                in hr_emp_charge_installments.hold_to_dt%type default null,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id => p_installment_id,
            p_new_status     => 'ON_HOLD',
            p_hold_from_dt   => p_hold_from_dt,
            p_hold_to_dt     => p_hold_to_dt,
            p_remarks        => p_remarks
        );
    end mark_installment_hold;

    procedure resume_installment (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id => p_installment_id,
            p_new_status     => 'PENDING',
            p_remarks        => p_remarks
        );

        update hr_emp_charge_installments
           set hold_from_dt = null,
               hold_to_dt   = null
         where installment_id = p_installment_id;
    end resume_installment;

    procedure mark_installment_waived (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id => p_installment_id,
            p_new_status     => 'WAIVED',
            p_remarks        => p_remarks
        );
    end mark_installment_waived;

    procedure mark_installment_bad_debt (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id => p_installment_id,
            p_new_status     => 'BAD_DEBT',
            p_remarks        => p_remarks
        );
    end mark_installment_bad_debt;

    procedure cancel_installment (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    ) is
    begin
        update_installment_status(
            p_installment_id => p_installment_id,
            p_new_status     => 'CANCELLED',
            p_remarks        => p_remarks
        );
    end cancel_installment;

    procedure cancel_charge (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type,
        p_remarks                   in varchar2 default null
    ) is
        l_remarks varchar2(500);
    begin
        if p_emp_charge_id is null then
            raise_err('Charge is required.');
        end if;

        select remarks
          into l_remarks
          from hr_emp_charges
         where emp_charge_id = p_emp_charge_id;

        append_remarks(l_remarks, p_remarks);

        update hr_emp_charges
           set approval_status = 'CANCELLED',
               payroll_processed_yn = 'N',
               remarks = l_remarks
         where emp_charge_id = p_emp_charge_id;

        update hr_emp_charge_installments
           set status_code = 'CANCELLED'
         where emp_charge_id = p_emp_charge_id
           and status_code in ('PENDING','ON_HOLD');
    end cancel_charge;

    procedure mark_charge_bad_debt (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type,
        p_remarks                   in varchar2 default null
    ) is
        l_remarks varchar2(500);
    begin
        if p_emp_charge_id is null then
            raise_err('Charge is required.');
        end if;

        select remarks
          into l_remarks
          from hr_emp_charges
         where emp_charge_id = p_emp_charge_id;

        append_remarks(l_remarks, p_remarks);

        update hr_emp_charges
           set approval_status = 'BAD_DEBT',
               payroll_processed_yn = 'Y',
               remarks = l_remarks
         where emp_charge_id = p_emp_charge_id;

        update hr_emp_charge_installments
           set status_code = 'BAD_DEBT'
         where emp_charge_id = p_emp_charge_id
           and status_code in ('PENDING','ON_HOLD');
    end mark_charge_bad_debt;

    function get_charge_balance (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type
    ) return number is
        l_total     number;
        l_closed    number;
    begin
        select amount
          into l_total
          from hr_emp_charges
         where emp_charge_id = p_emp_charge_id;

        select nvl(sum(amount),0)
          into l_closed
          from hr_emp_charge_installments
         where emp_charge_id = p_emp_charge_id
           and status_code in ('PROCESSED','WAIVED','BAD_DEBT');

        return l_total - l_closed;
    exception
        when no_data_found then
            return 0;
    end get_charge_balance;

    procedure reschedule_remaining_installments (
    p_emp_charge_id      in hr_emp_charges.emp_charge_id%type,
    p_first_due_dt       in date,
    p_no_of_installments in number,
    p_remarks            in varchar2 default null
) is
    l_balance      number;
    l_base_amt     number;
    l_last_amt     number;
    l_max_inst_no  number;
begin
    if p_emp_charge_id is null then
        raise_err('Charge is required.');
    end if;

    if p_first_due_dt is null then
        raise_err('First due date is required.');
    end if;

    if nvl(p_no_of_installments,0) <= 0 then
        raise_err('Number of installments must be greater than zero.');
    end if;

    l_balance := get_charge_balance(p_emp_charge_id);

    if l_balance <= 0 then
        raise_err('No remaining balance is available for rescheduling.');
    end if;

    update hr_emp_charge_installments
       set status_code = 'CANCELLED',
           remarks = case
                       when remarks is null then p_remarks
                       when p_remarks is null then remarks
                       else remarks || ' | Rescheduled: ' || p_remarks
                     end
     where emp_charge_id = p_emp_charge_id
       and status_code in ('PENDING','ON_HOLD');

    select nvl(max(installment_no),0)
      into l_max_inst_no
      from hr_emp_charge_installments
     where emp_charge_id = p_emp_charge_id;

    l_base_amt := round(l_balance / p_no_of_installments, 2);
    l_last_amt := l_balance - (l_base_amt * (p_no_of_installments - 1));

    for i in 1 .. p_no_of_installments loop
        insert into hr_emp_charge_installments (
            emp_charge_id,
            installment_no,
            due_dt,
            amount,
            status_code,
            remarks
        ) values (
            p_emp_charge_id,
            l_max_inst_no + i,
            add_months(p_first_due_dt, i - 1),
            case when i = p_no_of_installments then l_last_amt else l_base_amt end,
            'PENDING',
            'Rescheduled remaining balance. ' || p_remarks
        );
    end loop;

    update hr_emp_charges
       set payroll_processed_yn = 'N',
           approval_status = case
                               when approval_status = 'CLOSED' then 'APPROVED'
                               else approval_status
                             end
     where emp_charge_id = p_emp_charge_id;
end;

end hr_charges_pkg;
/
