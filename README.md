# Rider-Performance — HRMS & Payroll (Oracle Cloud)

Standalone Oracle APEX HRMS & Payroll system (Oracle Autonomous Database), built
in-house — no Oracle Fusion HCM integration. This app is the system of record
for employee data, assignments, and payroll.

## Modules (in progress)

- **Employee Profile** — employee/rider master data
- **Project Assignment** — assigning employees/riders to projects, zones, or routes
- **BIE (Bike/Equipment Issuance)** — tracking issuance/return of bikes and equipment
- **SIM Assignment** — tracking SIM card issuance per rider
- **Payroll** — since there's no Fusion Payroll to lean on, payroll calculation
  (salary, deductions, tax/EOBI/PF, overtime, leave) is owned entirely by this app —
  the highest-risk area to get right; needs careful review and test coverage.

> Naming note: confirm what "BIE" stands for in your team's usage so this doc and
> the schema match (e.g. Bike Issuance Entry vs. Bulk Import/Export).

## Repo structure

```
apex/application/     Full APEX app export, SPLIT format (one file per page/component)
db/tables/            DDL for custom tables (one file per table)
db/packages/          PL/SQL package specs & bodies
db/views/             Views
db/triggers/          Triggers
db/sequences/         Sequences
integration/          External integrations (bank/payment disbursement, SMS/notify, etc.), if any
docs/                 Architecture & data model notes
scripts/              One-off deploy/setup scripts
```

## Getting your APEX app into git (important)

Do **not** commit the single-file `f<app_id>.sql` export — it's unreadable in diffs
and merge conflicts become unresolvable. Instead export in **split** format:

**App Builder UI:** Export the app, choose *Split Files* option (available in
recent APEX versions) — this produces a folder tree per page/component.

**Or via SQLcl (recommended, scriptable):**
```sql
sql /nolog
SQLcl> apex export -applicationid <APP_ID> -expType APPLICATION -expOriginalIds -split
```
This drops a clean, git-friendly directory tree. Copy it into `apex/application/`.

## Getting custom DB objects into git

Export DDL per object (SQL Developer: right-click table → Export DDL, or
`dbms_metadata.get_ddl`) and drop one file per object into the matching `db/`
subfolder — this keeps history and reviews sane per-object instead of one giant dump.

## Workflow from here

1. Paste or upload your existing components (APEX pages, packages, table DDL) —
   either in chat or as files — and they'll be added here.
2. Each addition gets reviewed for: data model soundness (employee/project/BIE/SIM
   relationships), payroll calculation correctness and auditability, and standard
   APEX/PL-SQL practices (bind variables, authorization schemes, session state
   protection).
3. Once there's a real baseline, this README's module list becomes a proper
   architecture doc.
