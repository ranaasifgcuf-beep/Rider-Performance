# Organization Workbench: Groups → Orgs → Documents drill-down

Redesign of the org management flow: one page with three cascading regions
instead of separate flat pages, plus a proper multi-region Organization form
(the auto-generated grid was only surfacing a handful of columns — this
covers every column, including Trade License and government IDs).

Recommend **repurposing page 953 (Organization Workbench)** rather than
adding a new page number, since it's already meant to be the org browsing
entry point.

## Page structure

Two hidden page items: **`P_GROUP_ID`**, **`P_ORG_ID`** (both `Number`,
session state, no default — null means "show nothing selected / no filter").

### Region 1: Groups (`docs/reports/org_workbench_groups.sql`)
Interactive Report. Every group name is a link back to the *same page*,
setting `P_GROUP_ID` — this is the same `apex_page.get_url` same-page-link
pattern used throughout your app (bike/SIM request links etc.), so clicking
a group just reloads the page with that group selected, no custom JS needed.
The selected group's name renders bold.

### Region 2: Organizations under the selected group (`docs/reports/org_workbench_orgs.sql`)
Interactive Report, `where o.group_id = :P_GROUP_ID`. Shows org type, parent
org (self-join), Trade License number + an expiry badge (Expired/Near
Expiry/Valid — same convention as the bike Mulkiya/Insurance badges), a doc
count, and a pencil-icon link to the Organization form (edit).

**Before using this query**: replace every `&ORG_FORM_PAGE.` with the actual
page number of the Organization form you create in the step below.

Region 2 only makes sense once a group is selected — set its **Server-side
Condition** to `Item is NOT NULL` on `P_GROUP_ID` so it doesn't show (or
shows a "select a group" placeholder) until then.

### Region 3: Documents under the selected org (`docs/reports/org_docs_list.sql`, already built)
Same query from before, now with a pencil-icon edit link added — replace
`&DOC_FORM_PAGE.` with the actual Org Document form page number. Same
Server-side Condition idea: only show once `P_ORG_ID` is not null.

## The Organization form (replaces the "basic" grid)

**Create Page → Form**, table `HR_ORGS`. The wizard auto-generates every
column as a page item — the fix here isn't writing new SQL, it's
**reorganizing those auto-generated items into named regions** in Page
Designer (drag-and-drop) and converting a few to Select Lists. Suggested
regions:

**Basic Info**
- `P_GROUP_ID` → Select List. LOV: `select group_name d, group_id r from hr_groups where is_active = 'Y' order by group_name`. Default to the incoming `P_GROUP_ID` from the workbench page (Source → Item, or a Before Header process) so a new org is pre-assigned to the group you drilled into.
- `P_PARENT_ORG_ID` → Select List, for `ORG_TYPE = 'BRANCH'`. LOV: `select org_name || ' (' || org_code || ')' d, org_id r from hr_orgs where is_active = 'Y' and (org_id != :P_ORG_ID or :P_ORG_ID is null) order by org_name` — the `or :P_ORG_ID is null` guard matters, otherwise this LOV returns zero rows when creating a brand-new org (comparing `!=` against a null P_ORG_ID is never true in SQL).
- `P_ORG_CODE`, `P_ORG_NAME` — text fields, as generated.
- `P_ORG_TYPE` → Select List, Static Values: `COMPANY;COMPANY`, `BRANCH;BRANCH` (matches the `CHK_HR_ORG_TYPE` check constraint).
- `P_IS_MAIN_UNIT`, `P_IS_ACTIVE` — Switches (Y/N), as generated.
- `P_COMPANY_CODE` — as generated.

**Trade License & Government IDs**
- `P_TRADE_LIC_NO`, `P_TRADE_LIC_ISSUE_DT`, `P_TRADE_LIC_EXPIRY_DT`
- `P_MOL_CODE`, `P_MOHRE_ESTABLISHMENT_NO`, `P_IMMIGRATION_FILE_NO`, `P_ESTABLISHMENT_CARD_NO`
- `P_WPS_EMPLOYER_ID`, `P_TRN_NO`

**Address & Contact**
- `P_COUNTRY_ID` → Select List. LOV: `select country_name d, country_id r from ref_countries where is_active = 'Y' order by country_name`
- `P_CITY_ID` → Select List, **Cascading LOV Parent Item(s): `P_COUNTRY_ID`**. LOV: `select city_name d, city_id r from ref_cities where country_id = :P_COUNTRY_ID and is_active = 'Y' order by city_name`
- `P_ADDRESS_LINE1`, `P_ADDRESS_LINE2`, `P_PO_BOX`
- `P_CONTACT_PERSON`, `P_PHONE`, `P_MOBILE`, `P_EMAIL`

**Remarks**
- `P_REMARKS` — Textarea.

This mirrors the two/three-region layout style your Fleet Bike Form already
uses (Bike Details | Ownership) — same idea, just more regions since HR_ORGS
has considerably more columns.

## The Org Document form

Same as previously planned: **Create Page → Form** on `HR_ORG_DOCS`, then
change `P_ORG_ID` and `P_DOC_TYPE_CODE` to Select Lists (LOVs given in the
earlier message). Default `P_ORG_ID` from the workbench's `P_ORG_ID` so a
new document is pre-linked to the org you drilled into.

## Build order

1. Organization form page (need its page number for Region 2's edit link)
2. Org Document form page (need its page number for Region 3's edit link)
3. Repurpose 953 with the three regions + two hidden items, filling in both
   `&ORG_FORM_PAGE.` / `&DOC_FORM_PAGE.` placeholders with the real numbers
4. Test the drill-down: click a group → orgs appear → click an org →
   documents appear → edit pencils open the right forms pre-filled
