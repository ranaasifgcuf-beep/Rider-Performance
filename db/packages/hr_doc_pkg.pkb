create or replace package body hr_doc_pkg as

  procedure sync_identifier_from_doc(
    p_doc_id number
  ) is
    l_EMP_ID NUMBER;
    l_doc_type          hr_emp_docs.doc_type%type;
    l_doc_no            hr_emp_docs.doc_no%type;
    l_issue_dt          hr_emp_docs.issue_dt%type;
    l_expiry_dt         hr_emp_docs.expiry_dt%type;
    L_IDNT NUMBER;
  begin
    select EMP_ID,
           doc_type,
           doc_no,
           issue_dt,
           expiry_dt
      into l_EMP_ID,
           l_doc_type,
           l_doc_no,
           l_issue_dt,
           l_expiry_dt
      from hr_emp_docs
     where doc_id = p_doc_id;

    if  l_doc_type in ('PASSPORT','EID') then

    BEGIN
    SELECT COUNT(*)
    INTO L_IDNT
    FROM hr_emp_identifiers
    WHERE ID_TYPE= L_DOC_TYPE;
    END;

        IF NVL(L_IDNT,0) >0  THEN
                  update hr_emp_identifiers
                     set id_no      = nvl(l_doc_no, id_no),
                         issue_dt   = nvl(l_issue_dt, issue_dt),
                         expiry_dt  = nvl(l_expiry_dt, expiry_dt)
                         --updated_by = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
                         --updated_dt = systimestamp
                   where EMP_ID = L_EMP_ID;
        ELSE
            INSERT INTO hr_emp_identifiers
       (
       EMP_ID,
       ID_TYPE,
       ID_NO,
       ISSUE_DT,
       EXPIRY_DT,
       IS_PRIMARY,
       STATUS
            )
            VALUES
            (
                L_EMP_ID,
                l_doc_type,
                l_doc_no,
                l_issue_dt,
                l_expiry_dt,
                'Y',
                'ACTIVE'
            );
      END IF;
    end if;
  exception
    when no_data_found then
      null;
  end sync_identifier_from_doc;

  procedure save_doc(
    p_doc_id            in out number,
    p_emp_id            in number,
    p_doc_type          in varchar2,
    p_doc_no            in varchar2,
    p_issue_dt          in date,
    p_expiry_dt         in date,
    p_is_current_record in varchar2,
    p_related_id_rec_id in number,
    p_file_ref          in varchar2,
    p_remarks           in varchar2
  ) is
  begin
    if p_doc_id is null then
      insert into hr_emp_docs (
        emp_id,
        doc_type,
        doc_no,
        issue_dt,
        expiry_dt,
        is_current_record,
        related_id_rec_id,
        file_ref,
        remarks,
        created_by,
        created_dt
      )
      values (
        p_emp_id,
        upper(trim(p_doc_type)),
        upper(trim(p_doc_no)),
        p_issue_dt,
        p_expiry_dt,
        nvl(p_is_current_record,'Y'),
        p_related_id_rec_id,
        p_file_ref,
        p_remarks,
        coalesce(sys_context('APEX$SESSION','APP_USER'), user),
        systimestamp
      )
      returning doc_id into p_doc_id;
    else
      update hr_emp_docs
         set doc_type          = upper(trim(p_doc_type)),
             doc_no            = upper(trim(p_doc_no)),
             issue_dt          = p_issue_dt,
             expiry_dt         = p_expiry_dt,
             is_current_record = nvl(p_is_current_record,'Y'),
             related_id_rec_id = p_related_id_rec_id,
             file_ref          = p_file_ref,
             remarks           = p_remarks,
             updated_by        = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
             updated_dt        = systimestamp
       where doc_id = p_doc_id;
    end if;

    /*
      Make older same document inactive/current=N
      Rule = same employee + same doc type + same doc number
    */
    if p_doc_no is not null then
      update hr_emp_docs
         set 
             is_current_record = 'N',
             updated_by        = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
             updated_dt        = systimestamp
       where emp_id   = p_emp_id
         and doc_type = upper(trim(p_doc_type))
         and upper(trim(nvl(doc_no,'~'))) = upper(trim(p_doc_no))
         and doc_id <> p_doc_id;
    end if;

    /*
      Force saved row as current if it is latest same doc
    */
    update hr_emp_docs
       set 
           is_current_record = 'Y',
           updated_by        = coalesce(sys_context('APEX$SESSION','APP_USER'), user),
           updated_dt        = systimestamp
     where doc_id = p_doc_id;

    sync_identifier_from_doc(p_doc_id);

  end save_doc;

end hr_doc_pkg;
/
