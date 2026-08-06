create or replace package hr_approval_ui_pkg as

    function get_full_detail_url (
        p_module_code in varchar2,
        p_record_pk   in number
    ) return varchar2;

    function render_summary (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob;

    function render_extra_details (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number
    ) return clob;

    function render_approval_email (
        p_approval_step_id in number,
        p_task_id          in number
    ) return clob;

    procedure final_approve_module (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    );

    procedure final_reject_module (
        p_module_code in varchar2,
        p_record_pk   in number,
        p_approval_id in number,
        p_comments    in varchar2 default null
    );

end hr_approval_ui_pkg;
/
