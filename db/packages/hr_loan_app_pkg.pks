create or replace package hr_loan_app_pkg as

    procedure submit_for_approval (
        p_loan_txn_id in number
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


--- Manual Loan Approval ----

procedure submit_loan_for_approval (
    p_loan_id in number
);

function get_loan_subject (
    p_loan_id in number
) return varchar2;

function render_loan_summary (
    p_loan_id in number
) return clob;

function render_loan_email_summary (
    p_loan_id in number
) return clob;

procedure loan_approval_approved (
    p_loan_id in number
);

procedure loan_approval_rejected (
    p_loan_id in number,
    p_reason  in varchar2
);

end hr_loan_app_pkg;
/
