create or replace package body fleet_pkg as

    procedure raise_err(p_msg in varchar2) is
    begin
        raise_application_error(-20001, p_msg);
    end;

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
    ) is
        l_cnt number;
    begin
        if p_ownership_type not in ('COMPANY','RENTAL') then
            raise_err('Ownership Type must be COMPANY or RENTAL.');
        end if;

        if p_ownership_type = 'COMPANY' then
            if nvl(p_purchase_amount,0) < 1 then
                raise_err('Purchase Amount cannot be negative.');
            end if;

             if p_purchase_dt is null then
                raise_err('Purchase date is required for OWN bikes');
            end if;
        end if;

        if p_ownership_type = 'RENTAL' then
            if p_vendor_id is null then
                raise_err('Vendor is required for rental bikes.');
            end if;

            if nvl(p_current_monthly_rent,0) < 1 then
                raise_err('Current Monthly Rent must be greater than zero for rental bikes.');
            end if;
if p_contract_start_dt is  null or 
            p_contract_end_dt is  null then
            raise_err('Contract start and end date is required for rental bikes.');
        end if;


        if p_contract_start_dt is not null
           and p_contract_end_dt is not null
           and p_contract_end_dt < p_contract_start_dt then
            raise_err('Contract End Date cannot be earlier than Contract Start Date.');
        end if;

        end if;

          

        if p_plate_no is not null then
            select count(*)
              into l_cnt
              from fleet_bikes
             where upper(plate_no) = upper(p_plate_no)
               and nvl(bike_id,-1) <> nvl(p_bike_id,-1);

            if l_cnt > 0 then
                raise_err('Plate No already exists.');
            end if;
        end if;
    end validate_bike_master;


    function generate_bike_code (
        p_ownership_type         in fleet_bikes.ownership_type%type,
        p_vendor_id              in fleet_bikes.vendor_id%type default null
    ) return varchar2 is
        l_prefix      varchar2(30);
        l_next_num    number;
        l_code        varchar2(30);
    begin
        if p_ownership_type = 'RENTAL' then
            if p_vendor_id is null then
                raise_err('Vendor is required to generate bike code for rental bike.');
            end if;

            select nvl(short_name,'UNK')
              into l_prefix
              from fin_suppliers
             where supplier_id = p_vendor_id;
        else
            l_prefix := 'OWN';
        end if;

        select nvl(max(to_number(regexp_substr(bike_code, '[0-9]+$'))),0) + 1
          into l_next_num
          from fleet_bikes
         where upper(bike_code) like upper(l_prefix) || '-%';

        l_code := upper(l_prefix) || '-' || lpad(l_next_num, 5, '0');
        return l_code;

    exception
        when no_data_found then
            raise_err('Vendor short name not found in FIN_SUPPLIERS.');
    end generate_bike_code;


    function get_open_status_txn_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number is
        l_id number;
    begin
        select max(status_txn_id)
          into l_id
          from fleet_bike_status_txns
         where bike_id = p_bike_id
           and to_dt is null;
        return l_id;
    exception
        when no_data_found then
            return null;
    end get_open_status_txn_id;


    function get_open_custody_txn_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number is
        l_id number;
    begin
        select max(custody_txn_id)
          into l_id
          from fleet_bike_custody_txns
         where bike_id = p_bike_id
           and to_dt is null;
        return l_id;
    exception
        when no_data_found then
            return null;
    end get_open_custody_txn_id;


    function get_active_bike_assign_id (
        p_bike_id in fleet_bikes.bike_id%type
    ) return number is
        l_id number;
    begin
        select max(bike_assign_id)
          into l_id
          from fleet_bike_assignments
         where bike_id = p_bike_id
           and status_code = 'ACTIVE'
           and return_dt is null;
        return l_id;
    exception
        when no_data_found then
            return null;
    end get_active_bike_assign_id;


    function get_active_emp_bike_assign_id (
        p_emp_id in number
    ) return number is
        l_id number;
    begin
        select max(bike_assign_id)
          into l_id
          from fleet_bike_assignments
         where emp_id = p_emp_id
           and status_code = 'ACTIVE'
           and return_dt is null;
        return l_id;
    exception
        when no_data_found then
            return null;
    end get_active_emp_bike_assign_id;


    function get_current_bike_status (
        p_bike_id in fleet_bikes.bike_id%type
    ) return varchar2 is
        l_status fleet_bike_status_txns.bike_status_code%type;
    begin
        select bike_status_code
          into l_status
          from fleet_bike_status_txns
         where bike_id = p_bike_id
           and to_dt is null;
        return l_status;
    exception
        when no_data_found then
            return null;
    end get_current_bike_status;


    function is_bike_assignable (
        p_bike_id in fleet_bikes.bike_id%type
    ) return varchar2 is
        l_status        varchar2(30);
        l_assign_id     number;
        l_assignable_yn varchar2(1);
    begin
        l_status := get_current_bike_status(p_bike_id);
        l_assign_id := get_active_bike_assign_id(p_bike_id);

        if l_status is null then
            return 'N';
        end if;

        begin
            select is_assignable_yn
              into l_assignable_yn
              from fleet_ref_bike_statuses
             where status_code = l_status
               and is_active = 'Y';
        exception
            when no_data_found then
                return 'N';
        end;

        if l_assignable_yn <> 'Y' then
            return 'N';
        end if;

        if l_assign_id is not null then
            return 'N';
        end if;

        return 'Y';
    end is_bike_assignable;


    procedure change_bike_status (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_new_status             in fleet_bike_status_txns.bike_status_code%type,
        p_effective_ts           in timestamp,
        p_reason_code            in fleet_bike_status_txns.reason_code%type default null,
        p_remarks                in fleet_bike_status_txns.remarks%type default null
    ) is
        l_open_id       number;
        l_prev_from_ts  timestamp;
        l_exists        number;
    begin
        if p_bike_id is null then
            raise_err('Bike is required.');
        end if;

        if p_effective_ts is null then
            raise_err('Effective timestamp is required.');
        end if;

        select count(*)
          into l_exists
          from fleet_ref_bike_statuses
         where status_code = p_new_status
           and is_active = 'Y';

        if l_exists = 0 then
            raise_err('Invalid or inactive bike status.');
        end if;

        l_open_id := get_open_status_txn_id(p_bike_id);

        if l_open_id is not null then
            select from_dt
              into l_prev_from_ts
              from fleet_bike_status_txns
             where status_txn_id = l_open_id;

            if p_effective_ts < l_prev_from_ts then
                raise_err('New status timestamp cannot be earlier than current open status start timestamp.');
            end if;

            update fleet_bike_status_txns
               set to_dt = p_effective_ts
             where status_txn_id = l_open_id;
        end if;

        insert into fleet_bike_status_txns (
            bike_id, bike_status_code, from_dt, to_dt, reason_code, remarks
        ) values (
            p_bike_id, p_new_status, p_effective_ts, null, p_reason_code, p_remarks
        );
    end change_bike_status;


    procedure change_bike_custody (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_new_custody            in fleet_bike_custody_txns.custody_type_code%type,
        p_location_id            in fleet_bike_custody_txns.location_id%type default null,
        p_effective_ts           in timestamp,
        p_reason_code            in fleet_bike_custody_txns.reason_code%type default null,
        p_remarks                in fleet_bike_custody_txns.remarks%type default null
    ) is
        l_open_id       number;
        l_prev_from_ts  timestamp;
        l_exists        number;
        l_loc_exists    number;
    begin
        if p_bike_id is null then
            raise_err('Bike is required.');
        end if;

        if p_effective_ts is null then
            raise_err('Effective timestamp is required.');
        end if;

        select count(*)
          into l_exists
          from fleet_ref_custody_types
         where custody_type_code = p_new_custody
           and is_active = 'Y';

        if l_exists = 0 then
            raise_err('Invalid or inactive custody type.');
        end if;

        if p_location_id is not null then
            select count(*)
              into l_loc_exists
              from fleet_ref_custody_locations
             where location_id = p_location_id
               and custody_type_code = p_new_custody
               and is_active = 'Y';

            if l_loc_exists = 0 then
                raise_err('Selected custody location does not belong to selected custody type or is inactive.');
            end if;
        end if;

        l_open_id := get_open_custody_txn_id(p_bike_id);

        if l_open_id is not null then
            select from_dt
              into l_prev_from_ts
              from fleet_bike_custody_txns
             where custody_txn_id = l_open_id;

            if p_effective_ts < l_prev_from_ts then
                raise_err('New custody timestamp cannot be earlier than current open custody start timestamp.');
            end if;

            update fleet_bike_custody_txns
               set to_dt = p_effective_ts
             where custody_txn_id = l_open_id;
        end if;

        insert into fleet_bike_custody_txns (
            bike_id, custody_type_code, location_id, from_dt, to_dt, reason_code, remarks
        ) values (
            p_bike_id, p_new_custody, p_location_id, p_effective_ts, null, p_reason_code, p_remarks
        );
    end change_bike_custody;


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
    ) is
    begin
        validate_bike_master(
            p_bike_id              => null,
            p_plate_no             => p_plate_no,
            p_ownership_type       => p_ownership_type,
            p_vendor_id            => p_vendor_id,
            p_purchase_amount      => p_purchase_amount,
            p_current_monthly_rent => p_current_monthly_rent,
            p_contract_start_dt    => p_contract_start_dt,
            p_contract_end_dt      => p_contract_end_dt,
            p_purchase_dt => p_purchase_dt
        );

        p_bike_code := generate_bike_code(
            p_ownership_type => p_ownership_type,
            p_vendor_id      => p_vendor_id
        );

        insert into fleet_bikes (
            bike_code,
            plate_no,
            plate_emirate,
            chassis_no,
            engine_no,
            model_id,
            model_year,
            color_id,
            ownership_type,
            vendor_id,
            purchase_dt,
            purchase_amount,
            current_monthly_rent,
            contract_start_dt,
            contract_end_dt,
            remarks,
            is_active
        ) values (
            p_bike_code,
            p_plate_no,
            p_plate_emirate,
            p_chassis_no,
            p_engine_no,
            p_model_id,
            p_model_year,
            p_color_id,
            p_ownership_type,
            p_vendor_id,
            p_purchase_dt,
            p_purchase_amount,
            p_current_monthly_rent,
            p_contract_start_dt,
            p_contract_end_dt,
            p_remarks,
            'Y'
        )
        returning bike_id into p_bike_id;

        change_bike_status(
            p_bike_id      => p_bike_id,
            p_new_status   => p_initial_status,
            p_effective_ts => p_effective_ts,
            p_reason_code  => 'CREATE',
            p_remarks      => 'Initial bike creation'
        );

        change_bike_custody(
            p_bike_id      => p_bike_id,
            p_new_custody  => p_initial_custody,
            p_location_id  => p_initial_location_id,
            p_effective_ts => p_effective_ts,
            p_reason_code  => 'CREATE',
            p_remarks      => 'Initial bike creation'
        );
    end create_bike;


    procedure assign_bike (
        p_bike_id                in fleet_bikes.bike_id%type,
        p_emp_id                 in number,
        p_assign_ts              in timestamp,
        p_expected_return_ts     in timestamp default null,
        p_issue_condition        in fleet_bike_assignments.issue_condition%type default null,
        p_remarks                in fleet_bike_assignments.remarks%type default null,
        p_location_id            in fleet_bike_custody_txns.location_id%type default null,
        p_request_id             in fleet_bike_assignments.REF_REQUEST_ID%type default null
    ) is
        l_assignable varchar2(1);
        l_existing_id number;
    begin
        if p_bike_id is null then
            raise_err('Bike is required.');
        end if;

        if p_emp_id is null then
            raise_err('Employee is required.');
        end if;

        if p_assign_ts is null then
            raise_err('Assign timestamp is required.');
        end if;

        if p_expected_return_ts is not null and p_expected_return_ts < p_assign_ts then
            raise_err('Expected return timestamp cannot be earlier than assign timestamp.');
        end if;

        l_assignable := is_bike_assignable(p_bike_id);
        if l_assignable <> 'Y' then
            raise_err('Bike is not assignable.');
        end if;

        l_existing_id := get_active_emp_bike_assign_id(p_emp_id);
        if l_existing_id is not null then
            raise_err('Employee already has an active bike assignment.');
        end if;

        insert into fleet_bike_assignments (
            bike_id,
            emp_id,
            assign_dt,
            expected_return_dt,
            issue_condition,
            remarks,
            status_code,
            ref_request_id
        ) values (
            p_bike_id,
            p_emp_id,
            p_assign_ts,
            p_expected_return_ts,
            p_issue_condition,
            p_remarks,
            'ACTIVE',
            p_request_id
        );

        change_bike_status(
            p_bike_id      => p_bike_id,
            p_new_status   => 'ASSIGNED',
            p_effective_ts => p_assign_ts,
            p_reason_code  => 'ASSIGNMENT',
            p_remarks      => p_remarks
        );

        change_bike_custody(
            p_bike_id      => p_bike_id,
            p_new_custody  => 'EMPLOYEE',
            p_location_id  => p_location_id,
            p_effective_ts => p_assign_ts,
            p_reason_code  => 'ASSIGNMENT',
            p_remarks      => p_remarks
        );


    end assign_bike;


    procedure return_bike (
        p_bike_assign_id         in fleet_bike_assignments.bike_assign_id%type,
        p_return_ts              in timestamp,
        p_return_condition       in fleet_bike_assignments.return_condition%type default null,
        p_next_status            in fleet_bike_status_txns.bike_status_code%type,
        p_next_custody           in fleet_bike_custody_txns.custody_type_code%type,
        p_next_location_id       in fleet_bike_custody_txns.location_id%type default null,
        p_remarks                in varchar2 default null
    ) is
        l_bike_id    fleet_bike_assignments.bike_id%type;
        l_assign_ts  fleet_bike_assignments.assign_dt%type;
        l_status     fleet_bike_assignments.status_code%type;
    begin
        if p_bike_assign_id is null then
            raise_err('Bike Assignment is required.');
        end if;

        if p_return_ts is null then
            raise_err('Return timestamp is required.');
        end if;

        select bike_id, assign_dt, status_code
          into l_bike_id, l_assign_ts, l_status
          from fleet_bike_assignments
         where bike_assign_id = p_bike_assign_id;

        if l_status <> 'ACTIVE' then
            raise_err('Only active assignments can be returned.');
        end if;

        if p_return_ts < l_assign_ts then
            raise_err('Return timestamp cannot be earlier than assign timestamp.');
        end if;

        update fleet_bike_assignments
           set return_dt        = p_return_ts,
               return_condition = p_return_condition,
               remarks          = case
                                    when remarks is null then p_remarks
                                    when p_remarks is null then remarks
                                    else remarks || ' | ' || p_remarks
                                  end,
               status_code      = 'RETURNED'
         where bike_assign_id = p_bike_assign_id;

        change_bike_status(
            p_bike_id      => l_bike_id,
            p_new_status   => p_next_status,
            p_effective_ts => p_return_ts,
            p_reason_code  => 'RETURN',
            p_remarks      => p_remarks
        );

        change_bike_custody(
            p_bike_id      => l_bike_id,
            p_new_custody  => p_next_custody,
            p_location_id  => p_next_location_id,
            p_effective_ts => p_return_ts,
            p_reason_code  => 'RETURN',
            p_remarks      => p_remarks
        );
    end return_bike;


   function get_open_impound_id (
    p_bike_id in fleet_bikes.bike_id%type
) return number is
    l_impound_id number;
begin
    select max(impound_id)
      into l_impound_id
      from fleet_bike_impounds
     where bike_id = p_bike_id
       and status_code = 'ACTIVE'
       and release_ts is null;

    return l_impound_id;
end get_open_impound_id;

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
) is
    l_open_impound_id number;
    l_loc_cnt         number;
    l_emp_charge_id   number;
begin
    if p_bike_id is null then
        raise_err('Bike is required.');
    end if;

    if p_impound_start_ts is null then
        raise_err('Impound start date is required.');
    end if;

    if p_expected_release_ts is not null
       and p_expected_release_ts < p_impound_start_ts then
        raise_err('Expected release date cannot be earlier than impound start date.');
    end if;

    if p_impound_custody_code is null then
        raise_err('Impound custody is required.');
    end if;

    l_open_impound_id := get_open_impound_id(p_bike_id);

    if l_open_impound_id is not null then
        raise_err('An active impound case already exists for this bike.');
    end if;

    if p_impound_location_id is not null then
        select count(*)
          into l_loc_cnt
          from fleet_ref_custody_locations
         where location_id = p_impound_location_id
           and custody_type_code = p_impound_custody_code
           and is_active = 'Y';

        if l_loc_cnt = 0 then
            raise_err('Selected location does not belong to selected custody type.');
        end if;
    end if;

    if p_create_charge_yn = 'Y' then
        if p_emp_id is null then
            raise_err('Employee is required to create charge.');
        end if;

        if nvl(p_impound_cost,0) <= 0 then
            raise_err('Impound cost must be greater than zero to create charge.');
        end if;

        hr_charges_pkg.create_charge(
            p_emp_id                  => p_emp_id,
            p_charge_type             => 'IMPOUND',
            p_recurrence_type         => 'ONE_TIME',
            p_charge_ts               => p_impound_start_ts,
            p_amount                  => p_impound_cost,
            p_source_start_dt         => null,
            p_source_end_dt           => null,
            p_source_table_name       => null,
            p_source_row_id           => null,
            p_bike_id                 => p_bike_id,
            p_charge_to_employee_yn   => p_charge_to_employee_yn,
            p_excluded_from_charge_yn => p_excluded_from_charge_yn,
            p_approval_status         => 'APPROVED',
            p_payroll_deduction_code  => 'IMPOUND',
            p_remarks                 => 'Impound charge. ' || p_remarks,
            p_emp_charge_id           => l_emp_charge_id
        );

        if p_charge_due_dt is not null then
            hr_charges_pkg.create_single_installment(
                p_emp_charge_id => l_emp_charge_id,
                p_due_dt        => p_charge_due_dt,
                p_amount        => p_impound_cost,
                p_remarks       => 'Auto-created from impound case'
            );
        end if;
    end if;

    insert into fleet_bike_impounds (
        bike_id,
        emp_id,
        impound_start_ts,
        expected_release_ts,
        impound_custody_code,
        impound_location_id,
        impound_location_text,
        impound_reason,
        impound_cost,
        charge_to_employee_yn,
        excluded_from_charge_yn,
        emp_charge_id,
        status_code,
        remarks
    ) values (
        p_bike_id,
        p_emp_id,
        p_impound_start_ts,
        p_expected_release_ts,
        p_impound_custody_code,
        p_impound_location_id,
        p_impound_location_text,
        p_impound_reason,
        p_impound_cost,
        p_charge_to_employee_yn,
        p_excluded_from_charge_yn,
        l_emp_charge_id,
        'ACTIVE',
        p_remarks
    )
    returning impound_id into p_impound_id;

    if l_emp_charge_id is not null then
        update hr_emp_charges
           set source_table_name = 'FLEET_BIKE_IMPOUNDS',
               source_row_id     = p_impound_id
         where emp_charge_id = l_emp_charge_id;
    end if;

/* Close active assignment automatically due to impound */
update fleet_bike_assignments
   set return_dt          = p_impound_start_ts,
       return_condition   = 'Closed automatically due to impound case #' || p_impound_id,
       return_reason_code = 'IMPOUND_REPLACEMENT',
       status_code        = 'RETURNED',
       returned_by        = nvl(v('APP_USER'), user),
       remarks            = case
                               when remarks is null then 'Auto-closed due to impound. ' || p_remarks
                               else remarks || ' | Auto-closed due to impound. ' || p_remarks
                             end
 where bike_id = p_bike_id
   and status_code = 'ACTIVE'
   and return_dt is null;

    change_bike_status(
        p_bike_id      => p_bike_id,
        p_new_status   => 'IMPOUND',
        p_effective_ts => p_impound_start_ts,
        p_reason_code  => 'IMPOUND',
        p_remarks      => p_remarks
    );

    change_bike_custody(
        p_bike_id      => p_bike_id,
        p_new_custody  => p_impound_custody_code,
        p_location_id  => p_impound_location_id,
        p_effective_ts => p_impound_start_ts,
        p_reason_code  => 'IMPOUND',
        p_remarks      => p_remarks
    );
end open_bike_impound;

procedure release_bike_impound (
    p_impound_id         in fleet_bike_impounds.impound_id%type,
    p_release_ts         in fleet_bike_impounds.release_ts%type,
    p_next_status        in fleet_bike_status_txns.bike_status_code%type,
    p_next_custody       in fleet_bike_custody_txns.custody_type_code%type,
    p_next_location_id   in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
) is
    l_bike_id  fleet_bike_impounds.bike_id%type;
    l_start_ts fleet_bike_impounds.impound_start_ts%type;
    l_status   fleet_bike_impounds.status_code%type;
begin
    if p_impound_id is null then
        raise_err('Impound case is required.');
    end if;

    if p_release_ts is null then
        raise_err('Actual release date is required.');
    end if;

    if p_next_status is null then
        raise_err('Next status is required.');
    end if;

    if p_next_custody is null then
        raise_err('Next custody is required.');
    end if;

    select bike_id, impound_start_ts, status_code
      into l_bike_id, l_start_ts, l_status
      from fleet_bike_impounds
     where impound_id = p_impound_id;

    if l_status <> 'ACTIVE' then
        raise_err('Only active impound cases can be released.');
    end if;

    if p_release_ts < l_start_ts then
        raise_err('Actual release date cannot be earlier than impound start date.');
    end if;

    update fleet_bike_impounds
       set release_ts  = p_release_ts,
           status_code = 'RELEASED',
           remarks     = case
                            when remarks is null then p_remarks
                            when p_remarks is null then remarks
                            else remarks || ' | ' || p_remarks
                          end
     where impound_id = p_impound_id;

    change_bike_status(
        p_bike_id      => l_bike_id,
        p_new_status   => p_next_status,
        p_effective_ts => p_release_ts,
        p_reason_code  => 'IMPOUND_RELEASE',
        p_remarks      => p_remarks
    );

    change_bike_custody(
        p_bike_id      => l_bike_id,
        p_new_custody  => p_next_custody,
        p_location_id  => p_next_location_id,
        p_effective_ts => p_release_ts,
        p_reason_code  => 'IMPOUND_RELEASE',
        p_remarks      => p_remarks
    );
end release_bike_impound;


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
) is
    l_loc_cnt        number;
    l_emp_charge_id  number;
begin
    if p_bike_id is null then
        raise_err('Bike is required.');
    end if;

    if p_accident_dt is null then
        raise_err('Accident date is required.');
    end if;

    if p_accident_custody_code is null then
        raise_err('Accident custody is required.');
    end if;

    if p_fault_type is not null
       and p_fault_type not in ('EMPLOYEE','COMPANY','THIRD_PARTY') then
        raise_err('Invalid fault type.');
    end if;

    if p_accident_severity is not null
       and p_accident_severity not in ('MINOR','MAJOR','TOTAL_LOSS') then
        raise_err('Invalid accident severity.');
    end if;

    if p_charge_to_employee_yn not in ('Y','N') then
        raise_err('Charge to employee must be Y or N.');
    end if;

    if p_excluded_from_charge_yn not in ('Y','N') then
        raise_err('Excluded from charge must be Y or N.');
    end if;

    if p_create_charge_yn not in ('Y','N') then
        raise_err('Create charge must be Y or N.');
    end if;

    if p_accident_location_id is not null then
        select count(*)
          into l_loc_cnt
          from fleet_ref_custody_locations
         where location_id = p_accident_location_id
           and custody_type_code = p_accident_custody_code
           and is_active = 'Y';

        if l_loc_cnt = 0 then
            raise_err('Selected accident location does not belong to selected custody type or is inactive.');
        end if;
    end if;

    if p_create_charge_yn = 'Y' then
        if p_emp_id is null then
            raise_err('Employee is required when creating employee charge.');
        end if;

        if p_fault_type <> 'EMPLOYEE' then
            raise_err('Charge can be created only when fault type is EMPLOYEE.');
        end if;

        if nvl(p_estimated_cost,0) <= 0 then
            raise_err('Estimated cost must be greater than zero when creating charge.');
        end if;

        hr_charges_pkg.create_charge(
            p_emp_id                  => p_emp_id,
            p_charge_type             => 'ACCIDENT_RECOVERY',
            p_recurrence_type         => 'ONE_TIME',
            p_charge_ts               => cast(p_accident_dt as timestamp),
            p_amount                  => p_estimated_cost,
            p_source_start_dt         => null,
            p_source_end_dt           => null,
            p_source_table_name       => null,
            p_source_row_id           => null,
            p_bike_id                 => p_bike_id,
            p_charge_to_employee_yn   => p_charge_to_employee_yn,
            p_excluded_from_charge_yn => p_excluded_from_charge_yn,
            p_approval_status         => 'APPROVED',
            p_payroll_deduction_code  => 'ACCIDENT',
            p_remarks                 => 'Accident recovery. ' || p_remarks,
            p_emp_charge_id           => l_emp_charge_id
        );

        if p_charge_due_dt is not null then
            hr_charges_pkg.create_single_installment(
                p_emp_charge_id => l_emp_charge_id,
                p_due_dt        => p_charge_due_dt,
                p_amount        => p_estimated_cost,
                p_remarks       => 'Auto-created from accident case'
            );
        end if;
    end if;

    insert into fleet_bike_accidents (
        bike_id,
        emp_id,
        accident_dt,
        accident_location,
        police_report_no,
        fault_type,
        accident_severity,
        estimated_cost,
        charge_to_employee_yn,
        excluded_from_charge_yn,
        emp_charge_id,
        status_code,
        remarks
    ) values (
        p_bike_id,
        p_emp_id,
        p_accident_dt,
        p_accident_location,
        p_police_report_no,
        p_fault_type,
        p_accident_severity,
        p_estimated_cost,
        p_charge_to_employee_yn,
        p_excluded_from_charge_yn,
        l_emp_charge_id,
        'OPEN',
        p_remarks
    )
    returning accident_id into p_accident_id;

    if l_emp_charge_id is not null then
        update hr_emp_charges
           set source_table_name = 'FLEET_BIKE_ACCIDENTS',
               source_row_id     = p_accident_id
         where emp_charge_id = l_emp_charge_id;
    end if;

    update fleet_bike_assignments
       set return_dt          = cast(p_accident_dt as timestamp),
           return_condition   = 'Closed automatically due to accident case #' || p_accident_id,
           return_reason_code = 'ACCIDENT_REPLACEMENT',
           status_code        = 'RETURNED',
           returned_by        = nvl(v('APP_USER'), user),
           remarks            = case
                                   when remarks is null then 'Auto-closed due to accident. ' || p_remarks
                                   else remarks || ' | Auto-closed due to accident. ' || p_remarks
                                 end
     where bike_id = p_bike_id
       and status_code = 'ACTIVE'
       and return_dt is null;

    change_bike_status(
        p_bike_id      => p_bike_id,
        p_new_status   => 'ACCIDENT',
        p_effective_ts => cast(p_accident_dt as timestamp),
        p_reason_code  => 'ACCIDENT',
        p_remarks      => p_remarks
    );

    change_bike_custody(
        p_bike_id      => p_bike_id,
        p_new_custody  => p_accident_custody_code,
        p_location_id  => p_accident_location_id,
        p_effective_ts => cast(p_accident_dt as timestamp),
        p_reason_code  => 'ACCIDENT',
        p_remarks      => p_remarks
    );
end open_bike_accident;


procedure start_bike_repair (
    p_accident_id        in fleet_bike_accidents.accident_id%type,
    p_repair_start_dt    in fleet_bike_accidents.repair_start_dt%type,
    p_repair_custody     in fleet_bike_custody_txns.custody_type_code%type,
    p_repair_location_id in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
) is
    l_bike_id     fleet_bike_accidents.bike_id%type;
    l_accident_dt fleet_bike_accidents.accident_dt%type;
    l_status      fleet_bike_accidents.status_code%type;
begin
    if p_accident_id is null then
        raise_err('Accident case is required.');
    end if;

    if p_repair_start_dt is null then
        raise_err('Repair start date is required.');
    end if;

    if p_repair_custody is null then
        raise_err('Repair custody is required.');
    end if;

    select bike_id, accident_dt, status_code
      into l_bike_id, l_accident_dt, l_status
      from fleet_bike_accidents
     where accident_id = p_accident_id;

    if l_status <> 'OPEN' then
        raise_err('Only OPEN accident cases can be moved to repair.');
    end if;

    if p_repair_start_dt < l_accident_dt then
        raise_err('Repair start date cannot be earlier than accident date.');
    end if;

    update fleet_bike_accidents
       set repair_start_dt = p_repair_start_dt,
           status_code     = 'UNDER_REPAIR',
           remarks         = case
                               when remarks is null then p_remarks
                               when p_remarks is null then remarks
                               else remarks || ' | ' || p_remarks
                             end
     where accident_id = p_accident_id;

    change_bike_status(
        p_bike_id      => l_bike_id,
        p_new_status   => 'MAINTENANCE',
        p_effective_ts => cast(p_repair_start_dt as timestamp),
        p_reason_code  => 'REPAIR_START',
        p_remarks      => p_remarks
    );

    change_bike_custody(
        p_bike_id      => l_bike_id,
        p_new_custody  => p_repair_custody,
        p_location_id  => p_repair_location_id,
        p_effective_ts => cast(p_repair_start_dt as timestamp),
        p_reason_code  => 'REPAIR_START',
        p_remarks      => p_remarks
    );
end start_bike_repair;


procedure close_bike_accident (
    p_accident_id        in fleet_bike_accidents.accident_id%type,
    p_repair_end_dt      in fleet_bike_accidents.repair_end_dt%type,
    p_actual_cost        in fleet_bike_accidents.actual_cost%type default null,
    p_next_status        in fleet_bike_status_txns.bike_status_code%type,
    p_next_custody       in fleet_bike_custody_txns.custody_type_code%type,
    p_next_location_id   in fleet_bike_custody_txns.location_id%type default null,
    p_remarks            in varchar2 default null
) is
    l_bike_id         fleet_bike_accidents.bike_id%type;
    l_repair_start_dt fleet_bike_accidents.repair_start_dt%type;
    l_accident_dt     fleet_bike_accidents.accident_dt%type;
    l_status          fleet_bike_accidents.status_code%type;
begin
    if p_accident_id is null then
        raise_err('Accident case is required.');
    end if;

    if p_repair_end_dt is null then
        raise_err('Repair end date is required.');
    end if;

    if p_next_status is null then
        raise_err('Next status is required.');
    end if;

    if p_next_custody is null then
        raise_err('Next custody is required.');
    end if;

    if nvl(p_actual_cost,0) < 0 then
        raise_err('Actual cost cannot be negative.');
    end if;

    select bike_id, accident_dt, repair_start_dt, status_code
      into l_bike_id, l_accident_dt, l_repair_start_dt, l_status
      from fleet_bike_accidents
     where accident_id = p_accident_id;

    if l_status not in ('OPEN','UNDER_REPAIR') then
        raise_err('Only OPEN or UNDER_REPAIR accident cases can be closed.');
    end if;

    if p_repair_end_dt < l_accident_dt then
        raise_err('Repair end date cannot be earlier than accident date.');
    end if;

    if l_repair_start_dt is not null
       and p_repair_end_dt < l_repair_start_dt then
        raise_err('Repair end date cannot be earlier than repair start date.');
    end if;

    update fleet_bike_accidents
       set repair_end_dt = p_repair_end_dt,
           actual_cost   = p_actual_cost,
           status_code   = 'CLOSED',
           remarks       = case
                             when remarks is null then p_remarks
                             when p_remarks is null then remarks
                             else remarks || ' | ' || p_remarks
                           end
     where accident_id = p_accident_id;

    change_bike_status(
        p_bike_id      => l_bike_id,
        p_new_status   => p_next_status,
        p_effective_ts => cast(p_repair_end_dt as timestamp),
        p_reason_code  => 'ACCIDENT_CLOSE',
        p_remarks      => p_remarks
    );

    change_bike_custody(
        p_bike_id      => l_bike_id,
        p_new_custody  => p_next_custody,
        p_location_id  => p_next_location_id,
        p_effective_ts => cast(p_repair_end_dt as timestamp),
        p_reason_code  => 'ACCIDENT_CLOSE',
        p_remarks      => p_remarks
    );
end close_bike_accident;

end fleet_pkg;
/
