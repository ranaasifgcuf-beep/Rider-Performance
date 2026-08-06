create or replace package hr_bike_req_pkg as

    function create_request (
        p_emp_id               in number,
        p_request_type         in varchar2,
        p_priority             in varchar2 default 'NORMAL',
        p_required_by_dt       in date default null,
        p_requested_project_id in number default null,
        p_requested_city_id    in number default null,
        p_reason_code          in varchar2 default null,
        p_remarks              in varchar2 default null
    ) return number;

    procedure set_status (
        p_request_id in number,
        p_status     in varchar2,
        p_remarks    in varchar2 default null
    );

    procedure close_after_assignment (
        p_emp_id             in number,
        p_bike_id            in number default null,
        p_bike_assignment_id in number default null,
        p_request_id         in number default null
    );

end hr_bike_req_pkg;
/
