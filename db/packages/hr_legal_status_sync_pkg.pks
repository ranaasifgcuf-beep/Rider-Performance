create or replace package hr_legal_status_sync_pkg as
    procedure sync_working_status (
        p_emp_id       in number,
        p_legal_status in varchar2,
        p_reason       in varchar2 default null
    );
end hr_legal_status_sync_pkg;
/
