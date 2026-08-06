create or replace package hr_legal_profile_pkg as
    procedure ensure_profile (
        p_emp_id in number
    );

    procedure ensure_all_profiles;
end hr_legal_profile_pkg;
/
