create or replace package body hr_approval_ui_pkg as

    ----------------------------------------------------------------------
    -- Common helpers only
    ----------------------------------------------------------------------

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
        return 'AED ' || trim(to_char(nvl(p_amount,0), '999G999G999G990D00'));
    end amount_text;


    function field_html (
        p_label in varchar2,
        p_value in varchar2,
        p_class in varchar2 default null
    ) return clob
    is
    begin
        return
            '<div class="appr-field ' || apex_escape.html_attribute(p_class) || '">' ||
            '  <div class="appr-label">' || esc(p_label) || '</div>' ||
            '  <div class="appr-value">' || esc(p_value) || '</div>' ||
            '</div>';
    end field_html;


    function status_email_badge (
        p_status in varchar2
    ) return varchar2
    is
    begin
        if p_status = 'APPROVED' then
            return '<span style="background:#dcfce7;color:#166534;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Approved</span>';

        elsif p_status = 'REJECTED' then
            return '<span style="background:#fee2e2;color:#991b1b;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Rejected</span>';

        elsif p_status = 'TASK_CREATED' then
            return '<span style="background:#fef3c7;color:#92400e;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Current / Pending</span>';

        elsif p_status = 'PENDING' then
            return '<span style="background:#dbeafe;color:#1d4ed8;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Waiting</span>';

        elsif p_status = 'CANCELLED' then
            return '<span style="background:#f1f5f9;color:#475569;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">Cancelled</span>';

        else
            return '<span style="background:#f1f5f9;color:#475569;padding:3px 8px;border-radius:999px;font-size:11px;font-weight:bold;">' ||
                   apex_escape.html(nvl(p_status, '-')) ||
                   '</span>';
        end if;
    end status_email_badge;


    ----------------------------------------------------------------------
    -- Generic fallback summary
    ----------------------------------------------------------------------

    function render_generic_summary (
        p_approval_id in number
    ) return clob
    is
        l_html clob;
    begin
        for r in (
            select approval_subject,
                   module_code,
                   record_pk,
                   approval_amount,
                   request_status,
                   requested_by,
                   requested_dt
              from hr_approval_requests
             where approval_id = p_approval_id
        )
        loop
            l_html :=
                '<div class="appr-card">' ||
                '  <div class="appr-card-header">' ||
                '    <div>' ||
                '      <div class="appr-card-title">' || esc(r.approval_subject) || '</div>' ||
                '      <div class="appr-card-subtitle">' || esc(r.module_code) || '</div>' ||
                '    </div>' ||
                '    <div class="appr-status">' || esc(r.request_status) || '</div>' ||
                '  </div>' ||

                '  <div class="appr-grid">' ||
                     field_html('Module', r.module_code) ||
                     field_html('Record ID', to_char(r.record_pk)) ||
                     field_html('Amount', amount_text(r.approval_amount), 'amount') ||
                     field_html('Requested By', r.requested_by) ||
                     field_html('Requested Date', to_char(r.requested_dt, 'DD-MON-YYYY HH24:MI')) ||
                '  </div>' ||
                '</div>';
        end loop;

        if l_html is null then
            l_html :=
                '<div class="t-Alert t-Alert--warning">' ||
                'Approval request details not found.' ||
                '</div>';
        end if;

        return l_html;
    end render_generic_summary;


    ----------------------------------------------------------------------
    -- Dispatcher: full detail URL
    ----------------------------------------------------------------------

    function get_full_detail_url (
        p_module_code in varchar2,
        p_record_pk   in number
    ) return varchar2
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            return hr_pro_deal_app_pkg.get_full_detail_url(p_record_pk);

        /*
        Later, after HR_LOAN_APP_PKG is created:

        elsif p_module_code = 'LOAN_TXN' then
            return hr_loan_app_pkg.get_full_detail_url(p_record_pk);
        */

        
        elsif p_module_code = 'LOAN_TXN' then
    return hr_loan_app_pkg.get_full_detail_url(p_record_pk);
            elsif p_module_code = 'LOAN_MASTER' then

    return apex_page.get_url(
        p_page        => 171,
        p_items       => 'P171_LOAN_ID',
        p_values      => p_record_pk,
        p_clear_cache => '171'
    );
           else
            return null;
        end if;
    end get_full_detail_url;


    ----------------------------------------------------------------------
    -- Dispatcher: P25 transaction summary
    ----------------------------------------------------------------------

    function render_summary (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            return hr_pro_deal_app_pkg.render_summary(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );

        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            return hr_loan_app_pkg.render_summary(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
        */
        elsif p_module_code = 'LOAN_TXN' then
       return hr_loan_app_pkg.render_summary(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
        elsif p_module_code = 'LOAN_MASTER' then
    return hr_loan_app_pkg.render_loan_summary(p_record_pk);
        else
            return render_generic_summary(p_approval_id);
        end if;
    end render_summary;


    ----------------------------------------------------------------------
    -- Dispatcher: P25 extra transaction details
    ----------------------------------------------------------------------

    function render_extra_details (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            return hr_pro_deal_app_pkg.render_extra_details(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );

        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            return hr_loan_app_pkg.render_extra_details(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
        */
        elsif p_module_code = 'LOAN_TXN' then
    return hr_loan_app_pkg.render_extra_details(
        p_record_pk   => p_record_pk,
        p_approval_id => p_approval_id
    );
    elsif p_module_code = 'LOAN_MASTER' then
    return null;

        else
            return null;
        end if;
    end render_extra_details;


    ----------------------------------------------------------------------
    -- Dispatcher: email summary
    ----------------------------------------------------------------------

    function render_module_email_summary (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            return hr_pro_deal_app_pkg.render_email_summary(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );

elsif p_module_code = 'LOAN_TXN' then
    return hr_loan_app_pkg.render_email_summary(
        p_record_pk   => p_record_pk,
        p_approval_id => p_approval_id
    );
        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            return hr_loan_app_pkg.render_email_summary(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
        */

        else
            return null;
        end if;
    end render_module_email_summary;


    ----------------------------------------------------------------------
    -- Dispatcher: email details
    ----------------------------------------------------------------------

    function render_module_email_details (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            return hr_pro_deal_app_pkg.render_email_details(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
elsif p_module_code = 'LOAN_TXN' then
    return hr_loan_app_pkg.render_email_details(
        p_record_pk   => p_record_pk,
        p_approval_id => p_approval_id
    );
        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            return hr_loan_app_pkg.render_email_details(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id
            );
        */

        else
            return null;
        end if;
    end render_module_email_details;


    ----------------------------------------------------------------------
    -- Common email wrapper
    -- Module packages provide summary/details only.
    ----------------------------------------------------------------------

    function render_approval_email (
        p_approval_step_id in number,
        p_task_id          in number
    ) return clob
    is
        l_html              clob;
        l_task_url          varchar2(4000);
        l_full_detail_url   varchar2(4000);
        l_email_summary     clob;
        l_email_details     clob;
        l_path_rows         clob;
        l_path_html         clob;
        l_base_url          varchar2(4000);
    begin
        begin
            l_base_url := apex_mail.get_instance_url;
        exception
            when others then
                l_base_url := null;
        end;

        l_task_url :=
            l_base_url ||
            'f?p=' || v('APP_ID') || ':25:0::NO::P25_TASK_ID:' || p_task_id;

        for r in (
            select s.approval_step_id,
                   s.approval_id,
                   s.step_name,
                   s.approver_users,
                   ar.approval_subject,
                   ar.approval_amount,
                   ar.requested_by,
                   to_char(ar.requested_dt, 'DD-MON-YYYY HH24:MI') requested_dt,
                   ar.module_code,
                   ar.record_pk,
                   ar.request_status
              from hr_approval_request_steps s
              join hr_approval_requests ar
                on ar.approval_id = s.approval_id
             where s.approval_step_id = p_approval_step_id
        )
        loop
            l_path_rows       := null;
            l_path_html       := null;
            l_email_summary   := null;
            l_email_details   := null;
            l_full_detail_url := null;

            l_full_detail_url := get_full_detail_url(
                                     p_module_code => r.module_code,
                                     p_record_pk   => r.record_pk
                                 );

            l_email_summary := render_module_email_summary(
                                   p_module_code => r.module_code,
                                   p_record_pk   => r.record_pk,
                                   p_approval_id => r.approval_id
                               );

            l_email_details := render_module_email_details(
                                   p_module_code => r.module_code,
                                   p_record_pk   => r.record_pk,
                                   p_approval_id => r.approval_id
                               );

            ------------------------------------------------------------------
            -- Approval path
            ------------------------------------------------------------------
            for p in (
                select step_seq,
                       nvl(step_name, 'Level ' || step_seq) step_name,
                       approver_users,
                       step_status,
                       action_by,
                       to_char(action_dt, 'DD-MON-YYYY HH24:MI') action_date,
                       comments
                  from hr_approval_request_steps
                 where approval_id = r.approval_id
                 order by step_seq
            )
            loop
                l_path_rows := l_path_rows ||
                    '<tr>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(to_char(p.step_seq)) || '</td>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(p.step_name) || '</td>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(p.approver_users) || '</td>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || status_email_badge(p.step_status) || '</td>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(p.action_by) || '</td>' ||
                    '<td style="padding:8px;border-bottom:1px solid #eef2f7;">' || esc(p.action_date) || '</td>' ||
                    '</tr>';
            end loop;

            if l_path_rows is not null then
                l_path_html :=
                    '<div style="font-size:15px;font-weight:bold;color:#0f172a;margin:18px 0 8px 0;">Approval Path</div>' ||
                    '<table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border:1px solid #e5e7eb;">' ||
                    '<tr>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Seq</th>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Step</th>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Approver</th>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Status</th>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Action By</th>' ||
                    '<th align="left" style="padding:8px;background:#f8fafc;border-bottom:1px solid #e5e7eb;font-size:12px;color:#334155;">Action Date</th>' ||
                    '</tr>' ||
                    l_path_rows ||
                    '</table>';
            end if;

            ------------------------------------------------------------------
            -- Email body
            ------------------------------------------------------------------
            l_html :=
'<!DOCTYPE html>
<html>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;">

<table width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:20px;">
<tr>
<td align="center">

<table width="760" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:10px;border:1px solid #e5e7eb;overflow:hidden;">
<tr>
<td style="padding:18px 22px;background:#0f172a;color:#ffffff;">
  <div style="font-size:18px;font-weight:bold;">Approval Required</div>
  <div style="font-size:13px;color:#cbd5e1;margin-top:4px;">' || esc(r.approval_subject) || '</div>
</td>
</tr>

<tr>
<td style="padding:18px 22px;">

  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;border:1px solid #e5e7eb;">
    <tr>
      <td style="padding:9px;border-bottom:1px solid #eef2f7;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Module</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.module_code) || '</div>
      </td>
      <td style="padding:9px;border-bottom:1px solid #eef2f7;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Record ID</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(to_char(r.record_pk)) || '</div>
      </td>
      <td style="padding:9px;border-bottom:1px solid #eef2f7;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Amount</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;color:#9a3412;">' || amount_text(r.approval_amount) || '</div>
      </td>
      <td style="padding:9px;border-bottom:1px solid #eef2f7;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Status</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || status_email_badge(r.request_status) || '</div>
      </td>
    </tr>

    <tr>
      <td style="padding:9px;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Current Step</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.step_name) || '</div>
      </td>
      <td style="padding:9px;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Approver Users</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.approver_users) || '</div>
      </td>
      <td style="padding:9px;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Requested By</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.requested_by) || '</div>
      </td>
      <td style="padding:9px;background:#ffffff;">
        <div style="font-size:10px;text-transform:uppercase;color:#64748b;font-weight:bold;">Requested Date</div>
        <div style="font-size:12.5px;font-weight:bold;margin-top:4px;">' || esc(r.requested_dt) || '</div>
      </td>
    </tr>
  </table>' ||

  nvl(l_email_summary, '') ||
  nvl(l_email_details, '') ||
  nvl(l_path_html, '') ||

  '<div style="text-align:center;margin-top:20px;">' ||

    case
      when l_task_url is not null then
        '<a href="' || apex_escape.html_attribute(l_task_url) || '"
           style="display:inline-block;background:#2563eb;color:#ffffff;padding:11px 18px;text-decoration:none;border-radius:7px;font-size:14px;font-weight:bold;margin-right:8px;">
           Open Approval Task
         </a>'
      else
        null
    end ||

    case
      when l_full_detail_url is not null then
        '<a href="' || apex_escape.html_attribute(l_full_detail_url) || '"
           style="display:inline-block;background:#475569;color:#ffffff;padding:11px 18px;text-decoration:none;border-radius:7px;font-size:14px;font-weight:bold;">
           View Full Detail
         </a>'
      else
        null
    end ||

  '</div>

  <p style="font-size:12px;color:#64748b;margin-top:14px;text-align:center;">
    Please login to HRMS to approve, reject, or request information.
  </p>

</td>
</tr>
</table>

</td>
</tr>
</table>

</body>
</html>';

            return l_html;
        end loop;

        return
            '<html><body>' ||
            '<p>Approval required. Please open HRMS to review and take action.</p>' ||
            '</body></html>';

    end render_approval_email;


    ----------------------------------------------------------------------
    -- Final approval module dispatcher
    ----------------------------------------------------------------------

    procedure final_approve_module (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    )
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            hr_pro_deal_app_pkg.approval_approved(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id,
                p_comments    => p_comments
            );
            elsif p_module_code = 'LOAN_TXN' then
    hr_loan_app_pkg.approval_approved(
        p_record_pk   => p_record_pk,
        p_approval_id => p_approval_id,
        p_comments    => p_comments
    );
    elsif p_module_code = 'LOAN_MASTER' then
    hr_loan_app_pkg.loan_approval_approved(p_record_pk);

        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            hr_loan_app_pkg.approval_approved(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id,
                p_comments    => p_comments
            );
        */

        else
            raise_application_error(
                -20901,
                'No final approval handler defined for module: ' || p_module_code
            );
        end if;
    end final_approve_module;


    ----------------------------------------------------------------------
    -- Final rejection module dispatcher
    ----------------------------------------------------------------------

    procedure final_reject_module (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    )
    is
    begin
        if p_module_code = 'PRO_DEAL' then

            hr_pro_deal_app_pkg.approval_rejected(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id,
                p_reason      => p_comments
            );

        /*
        Later:

        elsif p_module_code = 'LOAN_TXN' then
            hr_loan_app_pkg.approval_rejected(
                p_record_pk   => p_record_pk,
                p_approval_id => p_approval_id,
                p_reason      => p_comments
            );
        */
    elsif p_module_code = 'LOAN_TXN' then
    hr_loan_app_pkg.approval_rejected(
        p_record_pk   => p_record_pk,
        p_approval_id => p_approval_id,
        p_reason      => p_comments
    );
elsif p_module_code = 'LOAN_MASTER' then
    hr_loan_app_pkg.loan_approval_rejected(p_record_pk, p_comments);
        else
            raise_application_error(
                -20902,
                'No rejection handler defined for module: ' || p_module_code
            );
        end if;
    end final_reject_module;

end hr_approval_ui_pkg;
/
