CREATE OR REPLACE EDITIONABLE TRIGGER "TRG_HR_PRO_DEALS_BIU" 
before insert or update on hr_pro_deals
for each row
declare
    l_year varchar2(4);
begin
    l_year := to_char(cast(systimestamp at time zone 'Asia/Dubai' as timestamp), 'YYYY');

    if inserting then
        if :new.deal_no is null then
            :new.deal_no := 'DEAL-' || l_year || '-' || lpad(hr_pro_deal_seq.nextval, 6, '0');
        end if;

        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.created_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);

        :new.approval_status    := nvl(:new.approval_status,'DRAFT');
        :new.agreement_required := nvl(:new.agreement_required,'Y');
        :new.agreement_printed  := nvl(:new.agreement_printed,'N');
        :new.agreement_signed   := nvl(:new.agreement_signed,'N');
        :new.loan_created       := nvl(:new.loan_created,'N');
        :new.pro_case_created   := nvl(:new.pro_case_created,'N');

        if :new.recoverable is null then
            select default_recoverable
              into :new.recoverable
              from hr_pro_deal_type_master
             where deal_type_code = :new.deal_type_code;
        end if;
    end if;

    if updating then
        :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'), user);
        :new.updated_dt := cast(systimestamp at time zone 'Asia/Dubai' as timestamp);
    end if;
end;
/

ALTER TRIGGER "TRG_HR_PRO_DEALS_BIU" ENABLE;
