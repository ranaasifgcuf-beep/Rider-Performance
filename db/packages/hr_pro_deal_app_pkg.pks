create or replace package hr_pro_deal_app_pkg as

    procedure submit_for_approval (
        p_deal_id in number
    );

    function get_subject (
        p_record_pk in number
    ) return varchar2;

    function get_full_detail_url (
        p_record_pk in number
    ) return varchar2;

    function render_summary (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob;

    function render_extra_details (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob;

    function render_email_summary (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob;

    function render_email_details (
        p_record_pk   in number,
        p_approval_id in number default null
    ) return clob;

    procedure approval_approved (
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    );

    procedure approval_rejected (
        p_record_pk   in number,
        p_approval_id in number,
        p_reason      in varchar2 default null
    );

end hr_pro_deal_app_pkg;
/
