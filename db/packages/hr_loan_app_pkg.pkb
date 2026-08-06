create or replace package body hr_loan_app_pkg as

    function esc (
        p_text in varchar2
    ) return varchar2
    is
    begin
        return apex_escape.html(nvl(p_text, '-'));
    end esc;


    function amount_text (
        p_amount in number
    ) return varchar2
    is
    begin
        return 'AED ' || trim(to_char(nvl(p_amount, 0), '999G999G999G990D00'));
    end amount_text;


    function txn_type_name (
        p_txn_type in varchar2
    ) return varchar2
    is
    begin
        return case p_txn_type
                 when 'MANUAL_PAYMENT'     then 'Manual Payment'
                 when 'WAIVER'             then 'Waiver'
                 when 'ADJUSTMENT'         then 'Adjustment'
                 when 'REVERSAL'           then 'Reversal'
                 when 'BAD_DEBT_WRITE_OFF' then 'Bad Debt Write-off'
                 when 'PAYROLL_DEDUCTION'  then 'Payroll Deduction'
                 else nvl(p_txn_type, '-')
               end;
    end txn_type_name;


    function get_subject (
        p_record_pk in number
    ) return varchar2
    is
        l_loan_no       hr_emp_loans.loan_no%type;
        l_employee_name varchar2(300);
        l_txn_type      varchar2(40);
        l_amount        number;
    begin
        select l.loan_no,
               e.emp_code || ' - ' || trim(e.first_name || ' ' || e.last_name),
               t.txn_type,
               t.amount
          into l_loan_no,
               l_employee_name,
               l_txn_type,
               l_amount
          from hr_emp_loan_txns t
          join hr_emp_loans l
            on l.loan_id = t.loan_id
          join hr_employees e
            on e.emp_id = t.emp_id
         where t.loan_txn_id = p_record_pk;

        return 'Loan ' || txn_type_name(l_txn_type) ||
               ' Approval - ' || l_loan_no ||
               ' - ' || l_employee_name ||
               ' - ' || amount_text(l_amount);

    exception
        when no_data_found then
            return 'Loan Transaction Approval';
    end get_subject;


    function get_full_detail_url (
        p_record_pk in number
    ) return varchar2
    is
        l_loan_id number;
    begin
        select loan_id
          into l_loan_id
          from hr_emp_loan_txns
         where loan_txn_id = p_record_pk;

        return apex_page.get_url(
            p_page        => 172,
            p_items       => 'P172_LOAN_TXN_ID',
            p_values      => p_record_pk,
            p_clear_cache => '172'
        );

    exception
        when no_data_found then
            return null;
    end get_full_detail_url;


    procedure submit_for_approval (
        p_loan_txn_id in number
    )
    is
        l_approval_id number;
        l_exists      number;
    begin
        for r in (
            select t.loan_txn_id,
                   t.loan_id,
                   t.txn_type,
                   t.amount,
                   t.approval_status,
                   l.loan_no
              from hr_emp_loan_txns t
              join hr_emp_loans l
                on l.loan_id = t.loan_id
             where t.loan_txn_id = p_loan_txn_id
        )
        loop
            if r.approval_status not in ('DRAFT', 'REJECTED', 'SUBMITTED') then
                raise_application_error(
                    -20851,
                    'Only Draft or Rejected loan transaction can be submitted for approval.'
                );
            end if;

            select count(*)
              into l_exists
              from hr_approval_requests
             where module_code = 'LOAN_TXN'
               and record_pk = p_loan_txn_id
               and request_status in ('SUBMITTED', 'PENDING', 'IN_PROGRESS');

            if l_exists > 0 then
                raise_application_error(
                    -20852,
                    'Approval request already exists for this loan transaction.'
                );
            end if;

            update hr_emp_loan_txns
               set approval_status = 'SUBMITTED',
                   updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
                   updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
             where loan_txn_id = p_loan_txn_id;

            /*
              For loan approval, ORG_ID is null for now.
              So your approval rule for LOAN_TXN should have ORG_ID null.
            */
            hr_approval_wf_pkg.start_approval(
                p_module_code   => 'LOAN_TXN',
                p_record_pk     => p_loan_txn_id,
                p_txn_type_code => r.txn_type,
                p_org_id        => null,
                p_amount        => r.amount,
                p_subject       => get_subject(p_loan_txn_id),
                p_approval_id   => l_approval_id
            );

            return;
        end loop;

        raise_application_error(-20853, 'Loan transaction request not found.');
    end submit_for_approval;


    function render_summary (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
        l_html clob;
        l_url  varchar2(4000);
    begin
        for r in (
            select t.loan_txn_id,
                   t.txn_type,
                   t.amount,
                   t.pay_mode,
                   t.reference_no,
                   t.approval_status,
                   t.remarks,
                   t.txn_date,
                   t.reversal_of_txn_id,
                   l.loan_no,
                   v.emp_code,
                   v.employee_name,
                   v.loan_type,
                   v.loan_amount,
                   v.emi_amount,
                   v.paid_amount,
                   v.waived_amount,
                   v.bad_debt_amount,
                   v.balance_amount
              from hr_emp_loan_txns t
              join hr_emp_loans l
                on l.loan_id = t.loan_id
              join hr_emp_loan_v v
                on v.loan_id = t.loan_id
             where t.loan_txn_id = p_record_pk
        )
        loop
            l_url := get_full_detail_url(p_record_pk);

            l_html :=
            '<div class="appr-summary-box">' ||

            '  <div class="appr-summary-title">' ||
            '    <div>' ||
            '      <span class="appr-summary-main">' || esc(r.loan_no) || '</span>' ||
            '      <span class="appr-summary-sub">Loan Transaction Approval</span>' ||
            '    </div>' ||
            '    <div class="appr-header-actions">' ||
            case
                when l_url is not null then
                    '      <a class="appr-open-detail" href="' || apex_escape.html_attribute(l_url) || '" target="_blank">' ||
                    '        <span class="fa fa-external-link"></span> Full Detail' ||
                    '      </a>'
                else null
            end ||
            '      <span class="appr-status-simple">' || esc(r.approval_status) || '</span>' ||
            '    </div>' ||
            '  </div>' ||

            '  <div class="appr-grid4">' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Employee</div>' ||
            '      <div class="appr-cell-value">' || esc(r.emp_code || ' - ' || r.employee_name) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Transaction Type</div>' ||
            '      <div class="appr-cell-value">' || esc(txn_type_name(r.txn_type)) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Request Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Current Balance</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.balance_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Loan Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.loan_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Paid Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.paid_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Waived Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.waived_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Bad Debt</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.bad_debt_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Pay Mode</div>' ||
            '      <div class="appr-cell-value">' || esc(r.pay_mode) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Reference No</div>' ||
            '      <div class="appr-cell-value">' || esc(r.reference_no) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Transaction Date</div>' ||
            '      <div class="appr-cell-value">' || esc(to_char(r.txn_date, 'DD-MON-YYYY')) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Loan Type</div>' ||
            '      <div class="appr-cell-value">' || esc(r.loan_type) || '</div>' ||
            '    </div>';

            if r.reversal_of_txn_id is not null then
                l_html := l_html ||
                '    <div class="appr-cell">' ||
                '      <div class="appr-cell-label">Reversal Of</div>' ||
                '      <div class="appr-cell-value">' || esc(to_char(r.reversal_of_txn_id)) || '</div>' ||
                '    </div>';
            end if;

            if r.remarks is not null then
                l_html := l_html ||
                '    <div class="appr-cell appr-cell-wide">' ||
                '      <div class="appr-cell-label">Reason / Remarks</div>' ||
                '      <div class="appr-cell-value">' || esc(r.remarks) || '</div>' ||
                '    </div>';
            end if;

            l_html := l_html ||
            '  </div>' ||
            '</div>';

            return l_html;
        end loop;

        return
            '<div class="appr-summary-box">' ||
            '  <div class="appr-summary-title">Loan transaction details not found</div>' ||
            '</div>';
    end render_summary;


    function render_extra_details (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
    begin
        return null;
    end render_extra_details;


    function render_email_summary (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
        l_html clob;
    begin
        for r in (
            select t.loan_txn_id,
                   t.txn_type,
                   t.amount,
                   t.pay_mode,
                   t.reference_no,
                   t.approval_status,
                   t.remarks,
                   t.txn_date,
                   l.loan_no,
                   v.emp_code,
                   v.employee_name,
                   v.loan_amount,
                   v.paid_amount,
                   v.waived_amount,
                   v.bad_debt_amount,
                   v.balance_amount
              from hr_emp_loan_txns t
              join hr_emp_loans l
                on l.loan_id = t.loan_id
              join hr_emp_loan_v v
                on v.loan_id = t.loan_id
             where t.loan_txn_id = p_record_pk
        )
        loop
            l_html :=
            '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border:1px solid #e5e7eb;margin-top:12px;">' ||

            '<tr>' ||
            '<td colspan="4" style="padding:10px;background:#f8fafc;border-bottom:1px solid #e5e7eb;">' ||
            '<div style="font-size:15px;font-weight:bold;color:#0f172a;">' || esc(r.loan_no) || '</div>' ||
            '<div style="font-size:12px;color:#64748b;margin-top:2px;">Loan ' || esc(txn_type_name(r.txn_type)) || ' Approval</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Employee</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.emp_code || ' - ' || r.employee_name) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Transaction Type</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(txn_type_name(r.txn_type)) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Request Amount</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Current Balance</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.balance_amount) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Loan Amount</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.loan_amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Paid</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.paid_amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Waived</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.waived_amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Bad Debt</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.bad_debt_amount) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Pay Mode</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.pay_mode) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Reference No</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.reference_no) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Txn Date</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(to_char(r.txn_date, 'DD-MON-YYYY')) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Status</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.approval_status) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td colspan="4" style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Remarks</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.remarks) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '</table>';

            return l_html;
        end loop;

        return null;
    end render_email_summary;


    function render_email_details (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
    begin
        return null;
    end render_email_details;


    procedure approval_approved (
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    )
    is
    begin
        update hr_emp_loan_txns
           set approval_status = 'APPROVED',
               approved_by     = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               approved_dt     = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               remarks         = case
                                    when p_comments is not null then
                                        nvl(remarks, '') || chr(10) ||
                                        'Approval Comments: ' || p_comments
                                    else remarks
                                  end
         where loan_txn_id = p_record_pk;

        if sql%rowcount = 0 then
            raise_application_error(-20854, 'Loan transaction not found for final approval.');
        end if;
    end approval_approved;


    procedure approval_rejected (
        p_record_pk   in number,
        p_approval_id in number,
        p_reason      in varchar2 default null
    )
    is
    begin
        update hr_emp_loan_txns
           set approval_status  = 'REJECTED',
               rejected_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               rejected_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               rejection_reason = p_reason,
               updated_by       = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt       = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where loan_txn_id = p_record_pk;

        if sql%rowcount = 0 then
            raise_application_error(-20855, 'Loan transaction not found for rejection.');
        end if;
    end approval_rejected;


    ---- Manual Loan Approval --
  function get_loan_subject (
    p_loan_id in number
) return varchar2
is
    l_subject varchar2(500);
begin
    select 'Manual Loan Request - ' ||
           loan_no ||
           ' - ' ||
           emp_code ||
           ' - ' ||
           employee_name ||
           ' - AED ' ||
           trim(to_char(nvl(loan_amount,0), '999G999G999G990D00'))
      into l_subject
      from hr_emp_loan_v
     where loan_id = p_loan_id;

    return l_subject;
exception
    when no_data_found then
        return 'Manual Loan Request - Loan ID ' || p_loan_id;
end get_loan_subject;

procedure submit_loan_for_approval (
    p_loan_id in number
)
is
    l_approval_id number;
    l_amount      number;
    l_status      varchar2(50);
begin
    select loan_amount,
           approval_status
      into l_amount,
           l_status
      from hr_emp_loans
     where loan_id = p_loan_id
       for update;

    if l_status not in ('DRAFT','REJECTED') then
        raise_application_error(
            -20801,
            'Only Draft or Rejected loan can be submitted for approval.'
        );
    end if;

    update hr_emp_loans
       set approval_status = 'SUBMITTED',
           updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
           updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
     where loan_id = p_loan_id;

    hr_approval_wf_pkg.start_approval(
        p_module_code   => 'LOAN_MASTER',
        p_record_pk     => p_loan_id,
        p_txn_type_code => null,
        p_org_id        => null,
        p_amount        => l_amount,
        p_subject       => get_loan_subject(p_loan_id),
        p_approval_id   => l_approval_id
    );
end submit_loan_for_approval;

function render_loan_summary (
    p_loan_id in number
) return clob
is
    l_html clob;

    function esc(p_text varchar2) return varchar2 is
    begin
        return apex_escape.html(nvl(p_text, '-'));
    end;

    function money(p_amount number) return varchar2 is
    begin
        return 'AED ' || trim(to_char(nvl(p_amount,0), '999G999G999G990D00'));
    end;
begin
    for r in (
        select loan_id,
               loan_no,
               emp_code,
               employee_name,
               loan_type,
               source_type,
               loan_amount,
               emi_amount,
               paid_amount,
               waived_amount,
               adjustment_amount,
               reversed_amount,
               bad_debt_amount,
               balance_amount,
               approval_status,
               status,
               issue_dt,
               start_month,
               remarks,
               agreed_advance_amount
          from hr_emp_loan_v
         where loan_id = p_loan_id
    )
    loop
        l_html :=
        '<div class="appr-summary-box">' ||

        '  <div class="appr-summary-title">' ||
        '    <div>' ||
        '      <span class="appr-summary-main">' || esc(r.loan_no) || '</span>' ||
        '      <span class="appr-summary-sub">Manual Loan Request</span>' ||
        '    </div>' ||
        '    <span class="appr-status-simple">' || esc(r.approval_status) || '</span>' ||
        '  </div>' ||

        '  <div class="appr-grid4">' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Employee</div>' ||
        '      <div class="appr-cell-value">' || esc(r.emp_code || ' - ' || r.employee_name) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Loan Type</div>' ||
        '      <div class="appr-cell-value">' || esc(r.loan_type) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Source Type</div>' ||
        '      <div class="appr-cell-value">' || esc(r.source_type) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Loan Status</div>' ||
        '      <div class="appr-cell-value">' || esc(r.status) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell amount">' ||
        '      <div class="appr-cell-label">Loan Amount</div>' ||
        '      <div class="appr-cell-value">' || money(r.loan_amount) || '</div>' ||
        '    </div>' ||
        '    <div class="appr-cell amount">' ||
'      <div class="appr-cell-label">Agreed Advance</div>' ||
'      <div class="appr-cell-value">' || money(r.agreed_advance_amount) || '</div>' ||
'    </div>' ||

        '    <div class="appr-cell amount">' ||
        '      <div class="appr-cell-label">EMI Amount</div>' ||
        '      <div class="appr-cell-value">' || money(r.emi_amount) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell amount">' ||
        '      <div class="appr-cell-label">Current Balance</div>' ||
        '      <div class="appr-cell-value">' || money(r.balance_amount) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Issue Date</div>' ||
        '      <div class="appr-cell-value">' || esc(to_char(r.issue_dt, 'DD-MON-YYYY')) || '</div>' ||
        '    </div>' ||

        '    <div class="appr-cell">' ||
        '      <div class="appr-cell-label">Recovery Start</div>' ||
        '      <div class="appr-cell-value">' || esc(to_char(r.start_month, 'MON-YYYY')) || '</div>' ||
        '    </div>';

        if r.remarks is not null then
            l_html := l_html ||
            '    <div class="appr-cell appr-cell-wide">' ||
            '      <div class="appr-cell-label">Remarks</div>' ||
            '      <div class="appr-cell-value">' || esc(r.remarks) || '</div>' ||
            '    </div>';
        end if;

        l_html := l_html ||
        '  </div>' ||
        '</div>';
    end loop;

    if l_html is null then
        l_html :=
        '<div class="appr-summary-box">' ||
        '  <div class="appr-summary-title">Loan request not found</div>' ||
        '</div>';
    end if;

    return l_html;
end render_loan_summary;

function render_loan_email_summary (
    p_loan_id in number
) return clob
is
begin
    return render_loan_summary(p_loan_id);
end render_loan_email_summary;

procedure loan_approval_approved (
    p_loan_id in number
)
is
begin
    update hr_emp_loans
       set approval_status = 'APPROVED',
           status          = 'ACTIVE',
           approved_by     = nvl(sys_context('APEX$SESSION','APP_USER'), user),
           approved_dt     = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
           updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
           updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
     where loan_id = p_loan_id
       and approval_status = 'SUBMITTED';
end loan_approval_approved;

procedure loan_approval_rejected (
    p_loan_id in number,
    p_reason  in varchar2
)
is
begin
    update hr_emp_loans
       set approval_status = 'REJECTED',
           rejection_reason = p_reason,
           updated_by       = nvl(sys_context('APEX$SESSION','APP_USER'), user),
           updated_dt       = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
     where loan_id = p_loan_id
       and approval_status = 'SUBMITTED';
end loan_approval_rejected;

end hr_loan_app_pkg;
/
