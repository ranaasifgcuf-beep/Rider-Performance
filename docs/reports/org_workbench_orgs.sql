select
  '<a href="' ||
  apex_page.get_url(
      p_items  => 'P_ORG_ID',
      p_values => o.org_id,
      p_reset_pagination => 'Yes'
  ) || '">' ||
  case when o.org_id = :P_ORG_ID
       then '<strong>' || o.org_name || '</strong>'
       else o.org_name
  end ||
  '</a>' as org_name,

  o.org_code,
  o.org_type,
  p.org_name as parent_org_name,

  o.trade_lic_no,
  o.trade_lic_expiry_dt,
  case
    when o.trade_lic_expiry_dt is null then
      '<span class="t-Badge">No Date</span>'
    when o.trade_lic_expiry_dt < trunc(sysdate) then
      '<span class="t-Badge t-Badge--danger">Expired</span>'
    when o.trade_lic_expiry_dt <= trunc(sysdate) + 30 then
      '<span class="t-Badge t-Badge--warning">Near Expiry</span>'
    else
      '<span class="t-Badge t-Badge--success">Valid</span>'
  end as trade_lic_status,

  case o.is_main_unit
    when 'Y' then '<span class="t-Badge t-Badge--info">Main Unit</span>'
    else null
  end as main_unit_flag,

  case o.is_active
    when 'Y' then '<span class="t-Badge t-Badge--success">Active</span>'
    else '<span class="t-Badge t-Badge--danger">Inactive</span>'
  end as is_active,

  '<a href="' ||
  apex_page.get_url(
      p_page   => 954,
      p_items  => 'P954_ORG_ID',
      p_values => o.org_id,
      p_request => 'EDIT'
  ) || '"><span class="fa fa-pencil" title="Edit Organization"></span></a>' as edit_link,

  (select count(*) from hr_org_docs d where d.org_id = o.org_id) as doc_count

from hr_orgs o
left join hr_orgs p
  on p.org_id = o.parent_org_id
where o.group_id = :P_GROUP_ID
order by o.org_name;
