create or replace package hr_pro_deal_pkg as

    procedure create_default_inclusions (
        p_deal_id in number
    );

    procedure submit_deal (
        p_deal_id in number
    );

    procedure approval_approved (
        p_deal_id in number
    );

    procedure approval_rejected (
        p_deal_id in number,
        p_reason  in varchar2
    );

    procedure create_loan_from_deal (
        p_deal_id in number
    );

end hr_pro_deal_pkg;
/
