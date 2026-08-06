create or replace package fleet_pkg as

    procedure validate_bike_master (
        p_bike_id                in fleet_bikes.bike_id%type default null,
        p_plate_no               in fleet_bikes.plate_no%type default null,
        p_ownership_type         in fleet_bikes.ownership_type%type,
        p_vendor_id              in fleet_bikes.vendor_id%type default null,
        p_purchase_amount        in fleet_bikes.purchase_amount%type default null,
        p_current_monthly_rent   in fleet_bikes.current_monthly_rent%type default null,
        p_contract_start_dt      in fleet_bikes.contract_start_dt%type default null,
        p_contract_end_dt        in fleet_bikes.contract_end_dt%type default null,
         p_purchase_dt        in fleet_bikes.purchase_dt%type default null
    );

    function generate_bike_code (
        p_ownership_type         in fleet_bikes.ownership_type%type,
        p_vendor_id              in fleet_bikes.vendor_id%type default null
    ) return varchar2;

    function get_open_status_txn_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number;

    function get_open_custody_txn_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number;

    function get_active_bike_assign_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number;

    function get_active_emp_bike_assign_id (
        p_emp_id in number
    ) return number;

    function get_current_bike_status (
        p_bike_id in fleet_bikes.bike_id%type
    ) return varchar2;

    function is_bike_assignable (
        p_bike_id in fleet_bikes.bike_id%type
    ) return varchar2;

    procedure change_bike_status (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_new_status             in fleet_bike_status_txns.bike_status_code%type,
        p_effective_ts           in timestamp,
        p_reason_code            in fleet_bike_status_txns.reason_code%type default null,
        p_remarks                in fleet_bike_status_txns.remarks%type default null
    );

    procedure change_bike_custody (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_new_custody            in fleet_bike_custody_txns.custody_type_code%type,
        p_location_id            in fleet_bike_custody_txns.location_id%type default null,
        p_effective_ts           in timestamp,
        p_reason_code            in fleet_bike_custody_txns.reason_code%type default null,
        p_remarks                in fleet_bike_custody_txns.remarks%type default null
    );

    procedure create_bike (
        p_plate_no               in fleet_bikes.plate_no%type default null,
        p_plate_emirate          in fleet_bikes.plate_emirate%type default null,
        p_chassis_no             in fleet_bikes.chassis_no%type default null,
        p_engine_no              in fleet_bikes.engine_no%type default null,
        p_model_id               in fleet_bikes.model_id%type default null,
        p_model_year             in fleet_bikes.model_year%type default null,
        p_color_id               in fleet_bikes.color_id%type default null,
        p_ownership_type         in fleet_bikes.ownership_type%type,
        p_vendor_id              in fleet_bikes.vendor_id%type default null,
        p_purchase_dt            in fleet_bikes.purchase_dt%type default null,
        p_purchase_amount        in fleet_bikes.purchase_amount%type default null,
        p_current_monthly_rent   in fleet_bikes.current_monthly_rent%type default null,
        p_contract_start_dt      in fleet_bikes.contract_start_dt%type default null,
        p_contract_end_dt        in fleet_bikes.contract_end_dt%type default null,
        p_remarks                in fleet_bikes.remarks%type default null,
        p_initial_status         in fleet_bike_status_txns.bike_status_code%type default 'AVAILABLE',
        p_initial_custody        in fleet_bike_custody_txns.custody_type_code%type default 'UNKNOWN',
        p_initial_location_id    in fleet_bike_custody_txns.location_id%type default null,
        p_effective_ts           in timestamp default systimestamp,
        p_bike_id                out fleet_bikes.bike_id%type,
        p_bike_code              out fleet_bikes.bike_code%type
    );

    procedure assign_bike (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_emp_id                 in number,
        p_assign_ts              in timestamp,
        p_expected_return_ts     in timestamp default null,
        p_issue_condition        in fleet_bike_assignments.issue_condition%type default null,
        p_remarks                in fleet_bike_assignments.remarks%type default null,
        p_location_id            in fleet_bike_custody_txns.location_id%type default null,
        p_request_id             in fleet_bike_assignments.REF_REQUEST_ID%type default null
    );

    procedure return_bike (
        p_bike_assign_id         in fleet_bike_assignments.bike_assign_id%type,
        p_return_ts              in timestamp,
        p_return_condition       in fleet_bike_assignments.return_condition%type default null,
        p_next_status            in fleet_bike_status_txns.bike_status_code%type,
        p_next_custody           in fleet_bike_custody_txns.custody_type_code%type,
        p_next_location_id       in fleet_bike_custody_txns.location_id%type default null,
        p_remarks                in varchar2 default null
    );

    function get_open_impound_id (
    p_bike_id in fleet_bikes.bike_id%type
) return number;

procedure open_bike_impound (
    p_bike_id                  in fleet_bike_impounds.bike_id%type,
    p_emp_id                   in fleet_bike_impounds.emp_id%type default null,
    p_impound_start_ts         in fleet_bike_impounds.impound_start_ts%type,
    p_expected_release_ts      in fleet_bike_impounds.expected_release_ts%type default null,
    p_impound_custody_code     in fleet_bike_impounds.impound_custody_code%type,
    p_impound_location_id      in fleet_bike_impounds.impound_location_id%type default null,
    p_impound_location_text    in fleet_bike_impounds.impound_location_text%type default null,
    p_impound_reason           in fleet_bike_impounds.impound_reason%type default null,
    p_impound_cost             in fleet_bike_impounds.impound_cost%type default null,
    p_charge_to_employee_yn    in fleet_bike_impounds.charge_to_employee_yn%type default 'N',
    p_excluded_from_charge_yn  in fleet_bike_impounds.excluded_from_charge_yn%type default 'N',
    p_create_charge_yn         in varchar2 default 'N',
    p_charge_due_dt            in date default null,
    p_remarks                  in fleet_bike_impounds.remarks%type default null,
    p_impound_id               out fleet_bike_impounds.impound_id%type
);

procedure release_bike_impound (
    p_impound_id         in fleet_bike_impounds.impound_id%type,
    p_release_ts         in fleet_bike_impounds.release_ts%type,
    p_next_status        in fleet_bike_status_txns.bike_status_code%type,
    p_next_custody       in fleet_bike_custody_txns.custody_type_code%type,
    p_next_location_id   in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
);

procedure open_bike_accident (
    p_bike_id                  in fleet_bike_accidents.bike_id%type,
    p_emp_id                   in fleet_bike_accidents.emp_id%type default null,
    p_accident_dt              in fleet_bike_accidents.accident_dt%type,
    p_accident_location        in fleet_bike_accidents.accident_location%type default null,
    p_police_report_no         in fleet_bike_accidents.police_report_no%type default null,
    p_fault_type               in fleet_bike_accidents.fault_type%type default null,
    p_accident_severity        in fleet_bike_accidents.accident_severity%type default null,
    p_accident_custody_code    in fleet_bike_custody_txns.custody_type_code%type,
    p_accident_location_id     in fleet_bike_custody_txns.location_id%type default null,
    p_estimated_cost           in fleet_bike_accidents.estimated_cost%type default null,
    p_charge_to_employee_yn    in fleet_bike_accidents.charge_to_employee_yn%type default 'N',
    p_excluded_from_charge_yn  in fleet_bike_accidents.excluded_from_charge_yn%type default 'N',
    p_create_charge_yn         in varchar2 default 'N',
    p_charge_due_dt            in date default null,
    p_remarks                  in fleet_bike_accidents.remarks%type default null,
    p_accident_id              out fleet_bike_accidents.accident_id%type
);

procedure start_bike_repair (
    p_accident_id        in fleet_bike_accidents.accident_id%type,
    p_repair_start_dt    in fleet_bike_accidents.repair_start_dt%type,
    p_repair_custody     in fleet_bike_custody_txns.custody_type_code%type,
    p_repair_location_id in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
);

procedure close_bike_accident (
    p_accident_id        in fleet_bike_accidents.accident_id%type,
    p_repair_end_dt      in fleet_bike_accidents.repair_end_dt%type,
    p_actual_cost        in fleet_bike_accidents.actual_cost%type default null,
    p_next_status        in fleet_bike_status_txns.bike_status_code%type,
    p_next_custody       in fleet_bike_custody_txns.custody_type_code%type,
    p_next_location_id   in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
);

end fleet_pkg;
/
