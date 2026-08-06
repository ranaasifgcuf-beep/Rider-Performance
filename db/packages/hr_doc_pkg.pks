create or replace package hr_doc_pkg as

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
  );

  procedure sync_identifier_from_doc(
    p_doc_id number
  );

end hr_doc_pkg;
/
