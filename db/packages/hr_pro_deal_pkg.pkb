create or replace package body hr_pro_deal_pkg as

    procedure create_default_inclusions (
        p_deal_id in number
    )
    is
    begin
        insert into hr_pro_deal_inclusions (
            deal_id,
            inclusion_code,
            included_yn
        )
        select p_deal_id,
               m.inclusion_code,
               'N'
          from hr_pro_deal_incl_master m
         where m.is_active = 'Y'
           and not exists (
               select 1
                 from hr_pro_deal_inclusions x
                where x.deal_id = p_deal_id
                  and x.inclusion_code = m.inclusion_code
           );
    end create_default_inclusions;


    procedure submit_deal (
        p_deal_id in number
    )
    is
        l_approval_id number;
        l_status      varchar2(30);
        l_deal_no     varchar2(50);
        l_org_id      number;
        l_deal_type   varchar2(40);
        l_amount      number;
    begin
        select approval_status,
               deal_no,
               org_id,
               deal_type_code,
               deal_amount
          into l_status,
               l_deal_no,
               l_org_id,
               l_deal_type,
               l_amount
          from hr_pro_deals
         where deal_id = p_deal_id;

        if l_status not in  ('DRAFT','REJECTED') then
            raise_application_error(-20201, 'Only Draft deals can be submitted.');
        end if;

        update hr_pro_deals
           set approval_status = 'SUBMITTED',
               submitted_by = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               submitted_dt = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where deal_id = p_deal_id;

        hr_approval_wf_pkg.start_approval(
            p_module_code   => 'PRO_DEAL',
            p_record_pk     => p_deal_id,
            p_txn_type_code => l_deal_type,
            p_org_id        => l_org_id,
            p_amount        => l_amount,
            p_subject       => 'PRO Deal Approval - ' || l_deal_no || ' - AED ' || to_char(l_amount),
            p_approval_id   => l_approval_id
        );
    end submit_deal;


    procedure approval_approved (
        p_deal_id in number
    )
    is
    begin
        update hr_pro_deals
           set approval_status = 'APPROVED',
               approved_by = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               approved_dt = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               updated_by = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where deal_id = p_deal_id
           and approval_status = 'SUBMITTED';

        create_loan_from_deal(p_deal_id);
    end approval_approved;


    procedure approval_rejected (
        p_deal_id in number,
        p_reason  in varchar2
    )
    is
    begin
        update hr_pro_deals
           set approval_status = 'REJECTED',
               rejected_by = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               rejected_dt = cast(systimestamp at time zone 'Asia/Dubai' as timestamp),
               rejection_reason = p_reason,
               updated_by = nvl(sys_context('APEX$SESSION','APP_USER'), user),
               updated_dt = cast(systimestamp at time zone 'Asia/Dubai' as timestamp)
         where deal_id = p_deal_id
           and approval_status = 'SUBMITTED';
    end approval_rejected;


    procedure create_loan_from_deal (
        p_deal_id in number
    )
    is
        l_loan_id number;
    begin
        for r in (
            select *
              from hr_pro_deals
             where deal_id = p_deal_id
               and approval_status = 'APPROVED'
               and recoverable = 'Y'
               and loan_created = 'N'
        )
        loop
            insert into hr_emp_loans (
                emp_id,
                loan_type,
                loan_amount,
                emi_amount,
                issue_dt,
                start_month,
                source_type,
                source_id,
                approval_status,
                status,
                remarks,
                agreed_advance_amount
            )
            values (
                r.emp_id,
                r.deal_type_code,
                r.deal_amount,
                r.emi_amount,
                trunc(sysdate),
                r.recovery_start_month,
                'PRO_DEAL',
                r.deal_id,
                'APPROVED',
                'ACTIVE',
                'Auto loan created from approved PRO deal ' || r.deal_no,
                r.deal_advance
            )
            returning loan_id into l_loan_id;

            update hr_pro_deals
               set loan_created = 'Y',
                   loan_id = l_loan_id
             where deal_id = r.deal_id;
        end loop;
    end create_loan_from_deal;

end hr_pro_deal_pkg;
/
