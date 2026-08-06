create or replace package hr_charges_pkg as

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
    );

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
    );

    procedure create_single_installment (
        p_emp_charge_id             in hr_emp_charge_installments.emp_charge_id%type,
        p_due_dt                    in hr_emp_charge_installments.due_dt%type,
        p_amount                    in hr_emp_charge_installments.amount%type,
        p_remarks                   in hr_emp_charge_installments.remarks%type default null
    );

    procedure create_equal_installments (
        p_emp_charge_id             in hr_emp_charge_installments.emp_charge_id%type,
        p_first_due_dt              in date,
        p_no_of_installments        in number,
        p_remarks                   in varchar2 default null
    );

    procedure mark_installment_processed (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_payroll_run_ref           in hr_emp_charge_installments.payroll_run_ref%type default null,
        p_remarks                   in varchar2 default null
    );

    procedure mark_installment_hold (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_hold_from_dt              in hr_emp_charge_installments.hold_from_dt%type default trunc(sysdate),
        p_hold_to_dt                in hr_emp_charge_installments.hold_to_dt%type default null,
        p_remarks                   in varchar2 default null
    );

    procedure resume_installment (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    );

    procedure mark_installment_waived (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    );

    procedure mark_installment_bad_debt (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    );

    procedure cancel_installment (
        p_installment_id            in hr_emp_charge_installments.installment_id%type,
        p_remarks                   in varchar2 default null
    );

    procedure cancel_charge (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type,
        p_remarks                   in varchar2 default null
    );

    procedure mark_charge_bad_debt (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type,
        p_remarks                   in varchar2 default null
    );

    function get_charge_balance (
        p_emp_charge_id             in hr_emp_charges.emp_charge_id%type
    ) return number;

    procedure reschedule_remaining_installments (
    p_emp_charge_id      in hr_emp_charges.emp_charge_id%type,
    p_first_due_dt       in date,
    p_no_of_installments in number,
    p_remarks            in varchar2 default null
);

end hr_charges_pkg;
/
