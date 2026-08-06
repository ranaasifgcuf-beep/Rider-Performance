create or replace package hr_approval_wf_pkg as

  function get_role_users (
        p_role_code in varchar2
    ) return varchar2;


    procedure start_approval (
        p_module_code   in varchar2,
        p_record_pk     in number,
        p_txn_type_code in varchar2,
        p_org_id        in number,
        p_amount        in number,
        p_subject       in varchar2,
        p_approval_id   out number
    );

    procedure get_next_step (
        p_approval_id     in number,
        p_step_id         out number,
        p_approver_users  out varchar2,
        p_task_subject    out varchar2,
        p_module_code     out varchar2,
        p_record_pk       out number
    );

    procedure mark_step_approved (
        p_step_id       in number,
        p_approver_user in varchar2,
        p_comments      in varchar2,
        p_has_next_step out varchar2
    );

    procedure mark_step_rejected (
        p_step_id       in number,
        p_approver_user in varchar2,
        p_comments      in varchar2
    );

    procedure final_approve (
        p_approval_id in number
    );

    procedure final_reject (
        p_approval_id in number,
        p_reason      in varchar2
    );

end hr_approval_wf_pkg;
/
