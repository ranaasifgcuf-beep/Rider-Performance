create or replace package body hr_pro_deal_app_pkg as

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


    function yes_no_badge (
        p_value in varchar2
    ) return varchar2
    is
    begin
        if nvl(p_value, 'N') = 'Y' then
            return '<span class="appr-pill yes">Yes</span>';
        else
            return '<span class="appr-pill no">No</span>';
        end if;
    end yes_no_badge;


    function yes_no_email_badge (
        p_value in varchar2
    ) return varchar2
    is
    begin
        if nvl(p_value, 'N') = 'Y' then
            return '<span style="background:#dcfce7;color:#166534;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Yes</span>';
        else
            return '<span style="background:#fee2e2;color:#991b1b;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">No</span>';
        end if;
    end yes_no_email_badge;


    function get_subject (
        p_record_pk in number
    ) return varchar2
    is
        l_deal_no       hr_pro_deals.deal_no%type;
        l_employee_name varchar2(300);
        l_deal_amount   number;
    begin
        select d.deal_no,
               trim(e.first_name || ' ' || e.last_name),
               d.deal_amount
          into l_deal_no,
               l_employee_name,
               l_deal_amount
          from hr_pro_deals d
          join hr_employees e
            on e.emp_id = d.emp_id
         where d.deal_id = p_record_pk;

        return 'PRO Deal Approval - ' ||
               l_deal_no || ' - ' ||
               l_employee_name || ' - ' ||
               amount_text(l_deal_amount);

    exception
        when no_data_found then
            return 'PRO Deal Approval';
    end get_subject;


    function get_full_detail_url (
        p_record_pk in number
    ) return varchar2
    is
    begin
        return apex_page.get_url(
            p_page        => 141,
            p_items       => 'P141_DEAL_ID',
            p_values      => p_record_pk,
            p_clear_cache => '141'
        );
    end get_full_detail_url;


    procedure submit_for_approval (
        p_deal_id in number
    )
    is
        l_approval_id number;
        l_exists      number;
    begin
        for r in (
            select d.deal_id,
                   d.deal_no,
                   d.deal_type_code,
                   d.org_id,
                   d.deal_amount,
                   d.approval_status
              from hr_pro_deals d
             where d.deal_id = p_deal_id
        )
        loop
            if r.approval_status not in ('DRAFT', 'REJECTED') then
                raise_application_error(
                    -20801,
                    'Only Draft or Rejected deal can be submitted for approval.'
                );
            end if;

            select count(*)
              into l_exists
              from hr_approval_requests
             where module_code = 'PRO_DEAL'
               and record_pk = p_deal_id
               and request_status in ('SUBMITTED', 'PENDING', 'IN_PROGRESS');

            if l_exists > 0 then
                raise_application_error(
                    -20802,
                    'Approval request already exists for this deal.'
                );
            end if;

            update hr_pro_deals
               set approval_status = 'SUBMITTED',
                   updated_by      = nvl(sys_context('APEX$SESSION','APP_USER'), user),
                   updated_dt      = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
             where deal_id = p_deal_id;

            hr_approval_wf_pkg.start_approval(
                p_module_code   => 'PRO_DEAL',
                p_record_pk     => p_deal_id,
                p_txn_type_code => r.deal_type_code,
                p_org_id        => r.org_id,
                p_amount        => r.deal_amount,
                p_subject       => get_subject(p_deal_id),
                p_approval_id   => l_approval_id
            );

            return;
        end loop;

        raise_application_error(-20803, 'Deal not found.');
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
            select d.deal_no,
                   e.emp_code,
                   trim(e.first_name || ' ' || e.last_name) employee_name,
                   o.org_name visa_company,
                   t.deal_type_name,
                   d.entry_status,
                   d.deal_advance,
                   d.deal_amount,
                   d.recoverable,
                   d.emi_amount,
                   d.recovery_start_month,
                   d.agreement_signed,
                   d.approval_status,
                   d.remarks
              from hr_pro_deals d
              join hr_employees e
                on e.emp_id = d.emp_id
              left join hr_orgs o
                on o.org_id = d.org_id
              join hr_pro_deal_type_master t
                on t.deal_type_code = d.deal_type_code
             where d.deal_id = p_record_pk
        )
        loop
            l_url := get_full_detail_url(p_record_pk);

            l_html :=
            '<div class="appr-summary-box">' ||

            '  <div class="appr-summary-title">' ||
            '    <div>' ||
            '      <span class="appr-summary-main">' || esc(r.deal_no) || '</span>' ||
            '      <span class="appr-summary-sub">' || esc(r.deal_type_name) || '</span>' ||
            '    </div>' ||
            '    <div class="appr-header-actions">' ||
            '      <a class="appr-open-detail" href="' || apex_escape.html_attribute(l_url) || '" target="_blank">' ||
            '        <span class="fa fa-external-link"></span> Full Detail' ||
            '      </a>' ||
            '      <span class="appr-status-simple">' || esc(r.approval_status) || '</span>' ||
            '    </div>' ||
            '  </div>' ||

            '  <div class="appr-grid4">' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Employee</div>' ||
            '      <div class="appr-cell-value">' || esc(r.emp_code || ' - ' || r.employee_name) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Visa Company</div>' ||
            '      <div class="appr-cell-value">' || esc(r.visa_company) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Entry Status</div>' ||
            '      <div class="appr-cell-value">' || esc(r.entry_status) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Recovery Start</div>' ||
            '      <div class="appr-cell-value">' || esc(to_char(r.recovery_start_month, 'MON-YYYY')) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Deal Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.deal_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">Deal Advance</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.deal_advance) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell amount">' ||
            '      <div class="appr-cell-label">EMI Amount</div>' ||
            '      <div class="appr-cell-value">' || amount_text(r.emi_amount) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Deal Type</div>' ||
            '      <div class="appr-cell-value">' || esc(r.deal_type_name) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Recoverable</div>' ||
            '      <div class="appr-cell-value">' || yes_no_badge(r.recoverable) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Agreement Signed</div>' ||
            '      <div class="appr-cell-value">' || yes_no_badge(r.agreement_signed) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Status</div>' ||
            '      <div class="appr-cell-value">' || esc(r.approval_status) || '</div>' ||
            '    </div>' ||

            '    <div class="appr-cell">' ||
            '      <div class="appr-cell-label">Deal No</div>' ||
            '      <div class="appr-cell-value">' || esc(r.deal_no) || '</div>' ||
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

            return l_html;
        end loop;

        return
            '<div class="appr-summary-box">' ||
            '  <div class="appr-summary-title">PRO Deal not found</div>' ||
            '</div>';
    end render_summary;


    function render_extra_details (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
        l_html clob;
        l_rows number := 0;
    begin
        l_html :=
            '<div class="appr-table-wrap">' ||
            '<table class="appr-mini-table">' ||
            '<thead>' ||
            '<tr>' ||
            '<th>Inclusion</th>' ||
            '<th>Included</th>' ||
            '<th>Amount</th>' ||
            '<th>Remarks</th>' ||
            '</tr>' ||
            '</thead><tbody>';

        for r in (
            select m.inclusion_name,
                   i.included_yn,
                   i.agreed_amount,
                   i.remarks
              from hr_pro_deal_inclusions i
              join hr_pro_deal_incl_master m
                on m.inclusion_code = i.inclusion_code
             where i.deal_id = p_record_pk
             order by m.seq_no
        )
        loop
            l_rows := l_rows + 1;

            l_html := l_html ||
                '<tr>' ||
                '<td>' || esc(r.inclusion_name) || '</td>' ||
                '<td>' || yes_no_badge(r.included_yn) || '</td>' ||
                '<td>' || amount_text(r.agreed_amount) || '</td>' ||
                '<td>' || esc(r.remarks) || '</td>' ||
                '</tr>';
        end loop;

        l_html := l_html || '</tbody></table></div>';

        if l_rows = 0 then
            return null;
        end if;

        return l_html;
    end render_extra_details;


    function render_email_summary (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob
    is
        l_html clob;
    begin
        for r in (
            select d.deal_no,
                   e.emp_code,
                   trim(e.first_name || ' ' || e.last_name) employee_name,
                   o.org_name visa_company,
                   t.deal_type_name,
                   d.entry_status,
                   d.deal_advance,
                   d.deal_amount,
                   d.recoverable,
                   d.emi_amount,
                   d.recovery_start_month,
                   d.agreement_signed,
                   d.approval_status,
                   d.remarks
              from hr_pro_deals d
              join hr_employees e
                on e.emp_id = d.emp_id
              left join hr_orgs o
                on o.org_id = d.org_id
              join hr_pro_deal_type_master t
                on t.deal_type_code = d.deal_type_code
             where d.deal_id = p_record_pk
        )
        loop
            l_html :=
            '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border:1px solid #e5e7eb;margin-top:12px;">' ||

            '<tr>' ||
            '<td colspan="4" style="padding:10px;background:#f8fafc;border-bottom:1px solid #e5e7eb;">' ||
            '<div style="font-size:15px;font-weight:bold;color:#0f172a;">' || esc(r.deal_no) || '</div>' ||
            '<div style="font-size:12px;color:#64748b;margin-top:2px;">' || esc(r.deal_type_name) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Employee</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.emp_code || ' - ' || r.employee_name) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Visa Company</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.visa_company) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Entry Status</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.entry_status) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Status</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.approval_status) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Deal Amount</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.deal_amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Deal Advance</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.deal_advance) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">EMI Amount</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.emi_amount) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;border-bottom:1px solid #eef2f7;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Recovery Start</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(to_char(r.recovery_start_month, 'MON-YYYY')) || '</div>' ||
            '</td>' ||
            '</tr>' ||

            '<tr>' ||
            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Recoverable</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || yes_no_email_badge(r.recoverable) || '</div>' ||
            '</td>' ||

            '<td style="padding:9px;">' ||
            '<div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Agreement Signed</div>' ||
            '<div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || yes_no_email_badge(r.agreement_signed) || '</div>' ||
            '</td>' ||

            '<td colspan="2" style="padding:9px;">' ||
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
        l_rows clob;
        l_html clob;
    begin
        for r in (
            select m.inclusion_name,
                   i.included_yn,
                   i.agreed_amount,
                   i.remarks
              from hr_pro_deal_inclusions i
              join hr_pro_deal_incl_master m
                on m.inclusion_code = i.inclusion_code
             where i.deal_id = p_record_pk
             order by m.seq_no
        )
        loop
            l_rows := l_rows ||
                '<tr>' ||
                '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(r.inclusion_name) || '</td>' ||
                '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || yes_no_email_badge(r.included_yn) || '</td>' ||
                '<td style="padding:8px;border-bottom:1px solid #eef2f7;font-weight:bold;color:#9a3412;">' || amount_text(r.agreed_amount) || '</td>' ||
                '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(r.remarks) || '</td>' ||
                '</tr>';
        end loop;

        if l_rows is null then
            return null;
        end if;

        l_html :=
            '<div style="font-size:15px;font-weight:bold;color:#0f172a;margin:18px 0 8px 0;">Transaction Details</div>' ||
            '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border:1px solid #e5e7eb;">' ||
            '<tr>' ||
            '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Inclusion</th>' ||
            '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Included</th>' ||
            '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Amount</th>' ||
            '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Remarks</th>' ||
            '</tr>' ||
            l_rows ||
            '</table>';

        return l_html;
    end render_email_details;


    procedure approval_approved (
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    )
    is
    begin
        /*
          Keep your existing working final approval logic.
          This protects your current PRO Deal auto-loan creation.
        */
        hr_pro_deal_pkg.approval_approved(p_record_pk);
    end approval_approved;


    procedure approval_rejected (
        p_record_pk   in number,
        p_approval_id in number,
        p_reason      in varchar2 default null
    )
    is
    begin
        /*
          Keep your existing working rejection logic.
        */
        hr_pro_deal_pkg.approval_rejected(p_record_pk, p_reason);
    end approval_rejected;

end hr_pro_deal_app_pkg;
/
