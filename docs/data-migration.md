# Migrating data (master tables, users, menus) to the new instance

`scripts/deploy_full.sql` only creates structure — no rows. This covers
moving actual data across, starting with config/reference data (not
transactional data like bike/employee history, which you'll likely want to
re-enter fresh on the new dev machine anyway).

## The 4-step process

1. **Disable FK constraints** on the new DB — `scripts/data_migration_01_disable_fks.sql`.
   This lets you load tables in **any order** without working out
   parent/child dependencies by hand.
2. **Load each table's data** (see method + table list below).
3. **Re-enable + validate FK constraints** — `scripts/data_migration_02_enable_fks.sql`.
   If a table references a parent you haven't loaded yet, this reports it
   and leaves that one constraint disabled — load the missing parent table
   and re-run the script (already-enabled constraints are skipped).
4. **Resync identity sequences** — `scripts/data_migration_03_resync_identity.sql`.
   You just inserted explicit ID values; without this, the next auto-generated
   ID (e.g. when the app creates a new record) can collide with one you just
   loaded. This must run **after** all data is loaded.

Run all three `.sql` scripts in the **new** instance's SQL Worksheet, Script mode.

## Loading the table data

The Database Actions "Download" dropdown on this instance doesn't offer an
Insert/SQL format (CSV/JSON only) — so use
**`scripts/generate_insert_statements.sql`** instead. It doesn't depend on
that UI feature at all; it generates `INSERT INTO "TABLE" ("COL1",...)
VALUES (...)` statements directly via PL/SQL for all 25 master/reference/
security tables in one run (explicit column names throughout, so the extra
ID column some tables now have in the new DB is simply omitted and
auto-generates).

1. **Old** DB → SQL Worksheet → paste in `generate_insert_statements.sql` →
   run in **Script mode** (the "Run Script" button, not the regular
   single-statement Run — same mode used for the earlier DDL export).
2. Output appears in the **Script Output** tab as plain text — one
   `-- ===== TABLE_NAME =====` section per table, followed by its INSERT
   statements. Use that pane's download/save icon to save it as one `.sql`
   file. Check for any `-- FAILED on ...` lines — that means that one
   table's data wasn't captured (schema/permission edge case) and needs
   handling separately.
3. **New** DB → SQL Worksheet → paste and run the saved file.

If a table you need isn't in the list (only the 25 master/reference/security
tables above are included), edit the `SYS.ODCIVARCHAR2LIST(...)` list near
the bottom of the script and add it.

## Tables to load first: master/reference data

```
core_years                     ref_countries
fleet_ref_bike_statuses        ref_cities            (needs ref_countries loaded first if FK is enabled --
fleet_ref_colors               ref_jobs                but with step 1 done, load order doesn't matter)
fleet_ref_custody_types
fleet_ref_custody_locations
fleet_ref_doc_types
fleet_ref_models
fleet_sim_operators
fleet_sim_status_master
hr_doc_type_master
hr_hiring_source_master
hr_org_doc_type_master
hr_pay_mode_master
hr_pro_deal_incl_master
hr_pro_deal_type_master
hr_status_master
```

## Tables to load: users, roles, menus (security/RBAC)

```
sec_modules
sec_perms
sec_roles
sec_role_perms
sec_menu            (self-referencing via parent_menu_id -- fine to load in any
                      row order since FKs are disabled during load)
sec_users
sec_user_roles
```

`sec_user_orgs` and `sec_user_projects` also reference `HR_ORGS` and
`HR_PROJECTS` (core HR tables, not in the master/security set above) — load
those two tables' data as well if you want `sec_user_orgs`/`sec_user_projects`
data to pass FK validation in step 3. Otherwise step 3 will flag them and you
can circle back later.

`sec_audit_log` is historical audit trail — skip it for a dev environment
unless you specifically want the old audit history.

## After this

Log into the new instance's APEX app, confirm dropdowns/lookups populate
correctly (proves master data loaded), and that user login + menu
navigation works (proves security data loaded).
