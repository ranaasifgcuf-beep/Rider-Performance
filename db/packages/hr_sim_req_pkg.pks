create or replace package hr_sim_req_pkg as

    function create_request (
        p_emp_id               in number,
        p_request_type         in varchar2,
        p_priority             in varchar2 default 'NORMAL',
        p_required_by_dt       in date default null,
        p_requested_project_id in number default null,
        p_requested_city_id    in number default null,
        p_current_sim_id       in number default null,
        p_reason_code          in varchar2 default null,
        p_remarks              in varchar2 default null
    ) return number;

    procedure mark_in_progress (
        p_request_id in number,
        p_remarks    in varchar2 default null
    );

    procedure cancel_request (
        p_request_id in number,
        p_reason     in varchar2 default null
    );

    procedure reject_request (
        p_request_id in number,
        p_reason     in varchar2
    );

    procedure close_after_assignment (
        p_emp_id        in number,
        p_sim_id        in number default null,
        p_sim_assign_id in number default null,
        p_request_id    in number default null
    );

    procedure close_after_return (
        p_emp_id     in number,
        p_sim_id     in number default null,
        p_request_id in number default null,
        p_remarks    in varchar2 default null
    );

end hr_sim_req_pkg;
/
