select
  '<a href="' ||
  apex_page.get_url(
      p_items  => 'P_GROUP_ID',
      p_values => g.group_id,
      p_reset_pagination => 'Yes'
  ) || '">' ||
  case when g.group_id = :P_GROUP_ID
       then '<strong>' || g.group_name || '</strong>'
       else g.group_name
  end ||
  '</a>' as group_name,

  g.group_code,
  g.owner_name,

  case g.is_active
    when 'Y' then '<span class="t-Badge t-Badge--success">Active</span>'
    else '<span class="t-Badge t-Badge--danger">Inactive</span>'
  end as is_active,

  (select count(*) from hr_orgs o where o.group_id = g.group_id) as org_count

from hr_groups g
order by g.group_name;
